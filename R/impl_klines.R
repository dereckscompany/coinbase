# File: R/impl_klines.R
# Shared window-pagination implementation for historical OHLCV backfill, used by
# coinbase_backfill_klines(). Coinbase's Exchange /candles endpoint returns only
# ~300 bars per request, so a date range is tiled into contiguous <=max_bars
# windows, each window is fetched, and the pages are stitched together
# (deduplicated by datetime), sorted ascending, and trimmed to CLOSED candles.
#
# This function is instance-free: it takes a .fetch_window(start, end) callback
# so it works identically whatever CoinbaseMarketData client (or test double)
# supplies the candles, and the window math is unit-tested offline.

# Split [from_s, to_s] (epoch SECONDS, doubles) into contiguous windows of at
# most `max_bars` candles of `step_s` seconds each -- the shape the Coinbase
# /candles endpoint needs, which caps a single response at ~300 bars. Each window
# is inclusive of both ends and covers up to `max_bars` candles; the next window
# starts one step after the previous end, so the windows tile the range without
# overlap or a boundary gap. Returns a list of list(start, end) in epoch seconds,
# empty when from > to.
#
# Epoch-second math stays in double, never int32: a day-granularity span past
# 2038 would overflow a 32-bit integer (see kucoin issue #40 for the same trap).
coinbase_candle_windows <- function(from_s, to_s, step_s, max_bars = 300L) {
  windows <- list()
  span_s <- (max_bars - 1L) * as.numeric(step_s)
  seg_start <- from_s
  while (seg_start <= to_s) {
    seg_end <- min(seg_start + span_s, to_s)
    windows[[length(windows) + 1L]] <- list(start = seg_start, end = seg_end)
    seg_start <- seg_end + step_s
  }
  return(windows)
}

# Fetch Deep OHLCV History from Coinbase by Window Pagination
#
# @param product_id Character; the pair symbol, e.g. "BTC-USD".
# @param granularity Character; a key of .COINBASE_GRANULARITY_MAP
#   ("1min", "5min", "15min", "1hour", "6hour", "1day").
# @param from POSIXct/numeric; start of the range.
# @param to POSIXct/numeric; end of the range.
# @param .fetch_window Function(start, end) -> Ohlcv data.table; fetches one
#   window's candles through the owning client. `start`/`end` are POSIXct.
# @param max_bars Integer; candles per window (the endpoint cap). Default 300.
# @param sleep Numeric; seconds to sleep between windows to respect rate limits.
# @param now POSIXct; the reference instant for the closed-candle trim. Defaults
#   to the current UTC time; injectable so the still-forming-edge drop is
#   deterministic in tests.
# @return An Ohlcv data.table (datetime, open, high, low, close, volume) sorted
#   ascending by datetime, holding only CLOSED candles; the typed empty table
#   when the range yields nothing.
coinbase_fetch_klines <- function(
  product_id,
  granularity = "1min",
  from,
  to,
  .fetch_window,
  max_bars = 300L,
  sleep = 0,
  now = lubridate::now("UTC")
) {
  if (!granularity %in% names(.COINBASE_GRANULARITY_MAP)) {
    abort_coinbase_validation_error(paste0(
      "Invalid granularity '",
      granularity,
      "'. Valid: ",
      paste(names(.COINBASE_GRANULARITY_MAP), collapse = ", ")
    ))
  }

  step_s <- .COINBASE_GRANULARITY_MAP[[granularity]]
  from_s <- as.numeric(lubridate::as_datetime(from, tz = "UTC"))
  to_s <- as.numeric(lubridate::as_datetime(to, tz = "UTC"))
  windows <- coinbase_candle_windows(from_s, to_s, step_s, max_bars)

  if (length(windows) == 0L) {
    return(empty_dt_ohlcv())
  }

  results <- vector("list", length(windows))
  for (i in seq_along(windows)) {
    w <- windows[[i]]
    results[[i]] <- .fetch_window(
      lubridate::as_datetime(w$start, tz = "UTC"),
      lubridate::as_datetime(w$end, tz = "UTC")
    )
    if (i < length(windows) && sleep > 0) {
      Sys.sleep(sleep)
    }
  }

  dts <- Filter(function(x) nrow(x) > 0L, results)
  if (length(dts) == 0L) {
    return(empty_dt_ohlcv())
  }

  dt <- data.table::rbindlist(dts)
  # Adjacent windows tile without overlap, but the endpoint is inclusive of both
  # ends, so dedup by datetime defends against any boundary repeat.
  dt <- unique(dt, by = "datetime")
  data.table::setorder(dt, datetime)
  # Keep only CLOSED candles: a bar opened at t closes at t + step, so the bar
  # still forming at the live edge is dropped and never persisted (a resume would
  # otherwise advance past it and never refresh it).
  dt <- dt[datetime + lubridate::dseconds(step_s) <= now]
  return(dt[])
}
