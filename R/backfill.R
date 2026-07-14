# File: R/backfill.R
# Standalone, instance-free deep trade backfill to CSV.

#' Backfill Coinbase Trade History to CSV
#'
#' Downloads deep tick history for one or more products and writes the results
#' incrementally to a CSV file. Supports resuming a partially completed backfill
#' by reading the existing file and continuing each product from its last
#' recorded trade. This is the foundation of the data-collection pipeline:
#' aggregate the resulting ticks with [trades_to_ohlcv()] for OHLCV at any
#' timeframe.
#'
#' Paging always begins at the most recent trade and walks backwards toward
#' `from`; for a fresh (non-resumed) run, leaving `from` as the default pulls a
#' bounded recent window rather than the product's entire history.
#'
#' @param symbols (character) product symbols (e.g. `c("BTC-USD", "ETH-USD")`).
#'   Must not be NULL or empty.
#' @param from (POSIXct | numeric) start of the backfill window. Defaults to one
#'   week ago. Tick volume is large, so widen this deliberately.
#' @param to (POSIXct | numeric) end of the window. Defaults to the current time.
#' @param file (scalar<character>) path to the output CSV. Data is appended
#'   incrementally so progress survives interruption.
#' @param base_url (scalar<character>) Advanced Trade API base URL.
#' @param exchange_base_url (scalar<character>) Exchange API base URL.
#' @param max_pages (scalar<numeric in [1, Inf]>) per-symbol cap on pages
#'   fetched. Default `Inf`.
#' @param sleep (scalar<numeric in [0, Inf[>) seconds to sleep between symbols to
#'   respect rate limits.
#' @param verbose (scalar<logical>) if `TRUE`, prints progress via
#'   [rlang::inform()].
#' @noassert file
#'
#' @return (scalar<character>) the file path (invisibly). If any symbols failed, a
#'   `"failures"` attribute is attached: a [data.table::data.table] with columns
#'   `symbol` and `error`.
#'
#' @importFrom lubridate as_datetime now dweeks
#' @importFrom rlang inform warn
#' @export
#'
#' @examples
#' \dontrun{
#' coinbase_backfill_trades(
#'   symbols = c("BTC-USD", "ETH-USD"),
#'   from = lubridate::as_datetime("2026-05-01"),
#'   file = "trades.csv"
#' )
#' }
coinbase_backfill_trades <- function(
  symbols,
  from = lubridate::now("UTC") - lubridate::dweeks(1),
  to = lubridate::now("UTC"),
  file,
  base_url = get_base_url(),
  exchange_base_url = get_exchange_base_url(),
  max_pages = Inf,
  sleep = 0.3,
  verbose = TRUE
) {
  if (is.null(symbols) || length(symbols) == 0L) {
    abort_coinbase_validation_error("`symbols` must be a non-empty character vector.")
  }
  for (s in symbols) {
    validate_symbol(s)
  }
  if (missing(file) || !is.character(file) || length(file) != 1L || !nzchar(file)) {
    abort_coinbase_validation_error("`file` must be a single non-empty path string.")
  }
  assert_args_coinbase_backfill_trades(
    symbols,
    from,
    to,
    base_url,
    exchange_base_url,
    max_pages,
    sleep,
    verbose
  )

  from <- lubridate::as_datetime(from, tz = "UTC")
  to <- lubridate::as_datetime(to, tz = "UTC")

  # Public market data needs no credentials.
  client <- CoinbaseMarketData$new(
    keys = NULL,
    base_url = base_url,
    exchange_base_url = exchange_base_url,
    async = FALSE
  )

  # Resume support: continue each symbol from its last recorded trade. We resume
  # from the last stored time *inclusively* (not offset forward) and drop
  # already-stored trade_ids before writing. Offsetting the start time forward
  # would skip any other trades sharing that same second, since ticks are
  # sub-second; deduping on trade_id avoids both gaps and duplicate rows.
  last_times <- list()
  existing_ids <- list()
  file_exists <- file.exists(file)
  resumable <- FALSE
  if (file_exists) {
    existing <- data.table::fread(file)
    if (nrow(existing) > 0L && all(c("symbol", "timestamp", "trade_id") %in% names(existing))) {
      existing[, timestamp := lubridate::as_datetime(timestamp, tz = "UTC")]
      maxes <- existing[, list(max_time = max(timestamp)), by = symbol]
      last_times <- stats::setNames(as.list(maxes$max_time), maxes$symbol)
      ids <- existing[, list(ids = list(unique(trade_id))), by = symbol]
      existing_ids <- stats::setNames(ids$ids, ids$symbol)
      resumable <- TRUE
    } else if (nrow(existing) > 0L) {
      # File exists, has rows, but wrong columns: refuse to append headerless,
      # mismatched data onto it.
      abort_coinbase_validation_error(paste0(
        "Output file '",
        file,
        "' exists but lacks the required columns ",
        "(symbol, trade_id, timestamp). Refusing to append; remove or fix the file."
      ))
    }
  }

  failures <- list()
  # Only append (skip header) when there is a valid, non-empty file to extend.
  wrote_any <- resumable
  total <- length(symbols)

  for (i in seq_len(total)) {
    sym <- symbols[[i]]
    sym_from <- from
    # On resume, walk the full window back to the last stored trade: combining a
    # finite max_pages with a resume could truncate the newest pages and strand a
    # permanent gap (the next resume jumps past it from max(time)).
    sym_max_pages <- max_pages
    if (!is.null(last_times[[sym]])) {
      sym_from <- last_times[[sym]]
      if (is.finite(max_pages)) {
        sym_max_pages <- Inf
        if (verbose) {
          rlang::inform(sprintf("[%d/%d] %s: resuming; ignoring max_pages to avoid a gap", i, total, sym))
        }
      }
    }

    if (sym_from > to) {
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s: skipped (already up to date)", i, total, sym))
      }
      next
    }

    result <- tryCatch(
      client$get_trades_history(sym, start = sym_from, end = to, max_pages = sym_max_pages),
      error = function(e) e
    )

    if (inherits(result, "error")) {
      failures[[length(failures) + 1L]] <- list(symbol = sym, error = conditionMessage(result))
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s: ERROR %s", i, total, sym, conditionMessage(result)))
      }
      next
    }

    # Drop trades already stored for this symbol (boundary-second overlap on resume).
    if (!is.null(existing_ids[[sym]])) {
      result <- result[!trade_id %in% existing_ids[[sym]]]
    }

    if (nrow(result) == 0L) {
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s: 0 rows", i, total, sym))
      }
      next
    }

    result[, symbol := sym]
    data.table::setcolorder(result, c("symbol", "trade_id", "side", "price", "size", "timestamp"))
    data.table::fwrite(result, file, append = wrote_any)
    wrote_any <- TRUE

    if (verbose) {
      rlang::inform(sprintf("[%d/%d] %s: %d trades", i, total, sym, nrow(result)))
    }

    if (sleep > 0 && i < total) {
      Sys.sleep(sleep)
    }
  }

  if (length(failures) > 0L) {
    fail_dt <- data.table::rbindlist(failures)
    attr(file, "failures") <- fail_dt[]
    rlang::warn(sprintf("%d symbol(s) failed; see the 'failures' attribute.", nrow(fail_dt)))
  }

  return(invisible(assert_return_coinbase_backfill_trades(file)))
}

#' Backfill Coinbase OHLCV Candles to CSV
#'
#' @description
#' Downloads historical price candles (open/high/low/close/volume) for one or
#' more products across one or more timeframes and writes them to a CSV file, one
#' row per candle. Coinbase only returns about 300 candles per request, so this
#' walks the whole date range for you, page by page, and appends as it goes.
#' Re-running it against the same file resumes from the last saved candle, so an
#' interrupted run is safe to just restart. This is the Coinbase sibling of
#' [coinbase::coinbase_backfill_trades()] and mirrors the kucoin/binance
#' `*_backfill_klines()` contract.
#'
#' @details
#' **Window mechanics.** The Coinbase Exchange `/candles` endpoint caps a single
#' response at ~300 bars, so each `(symbol, timeframe)` range is tiled into
#' contiguous windows of at most `max_bars` bars driven over
#' `CoinbaseMarketData$get_ohlcv()`. Windows are inclusive of both ends and the
#' next starts one step past the previous end, so they tile the range without a
#' boundary gap. Epoch-second arithmetic is done in double, never 32-bit integer,
#' so day-granularity spans past 2038 cannot silently overflow.
#'
#' **Resume semantics.** When `file` already holds rows for a `(symbol,
#' timeframe)`, the fetch restarts *inclusively* from that combination's last
#' stored candle and the boundary duplicate is collapsed — only strictly-newer
#' candles are appended — so a restart can neither strand a gap nor repeat a row.
#' A combination whose last stored candle already reaches `to` is skipped as up to
#' date.
#'
#' **Dedup and closed candles.** Pages are unioned and deduplicated by
#' `datetime`, sorted ascending. Only *closed* candles are written: the bar still
#' forming at the live edge (open time `t` where `t + step > now`) is dropped so a
#' half-built candle is never persisted (a resume would otherwise advance past it
#' and never refresh it).
#'
#' **Failures.** Each failed `(symbol, timeframe)` combination raises one
#' [rlang::warn()], and after the loop a final summary warning lists the count and
#' the affected combinations (the kucoin/binance convention downstream failure
#' ledgers key on). No failure data is hidden on the return value.
#'
#' @param symbols (character) product symbols (e.g. `c("BTC-USD", "ETH-USD")`).
#'   Must not be NULL or empty.
#' @param timeframes (character) candle timeframes; the Coinbase granularities
#'   `"1min"`, `"5min"`, `"15min"`, `"1hour"`, `"6hour"`, `"1day"`. Default
#'   `"1day"`.
#' @param from (POSIXct | numeric) start of the backfill window. Defaults to one
#'   year ago.
#' @param to (POSIXct | numeric) end of the backfill window. Defaults to the
#'   current time.
#' @param file (scalar<character>) path to the output CSV. Data is appended
#'   incrementally so progress survives interruption.
#' @param base_url (scalar<character>) Advanced Trade API base URL.
#' @param exchange_base_url (scalar<character>) Exchange API base URL (the host
#'   that serves `/candles`).
#' @param max_bars (scalar<count in [1, Inf[>) candles per request window (the
#'   endpoint cap). Default 300.
#' @param sleep (scalar<numeric in [0, Inf[>) seconds to sleep between request
#'   windows and between combinations to respect rate limits.
#' @param verbose (scalar<logical>) if `TRUE`, prints progress via
#'   [rlang::inform()].
#' @noassert file
#'
#' @return (scalar<character>) the file path (invisibly). The written CSV has
#'   columns `datetime`, `open`, `high`, `low`, `close`, `volume`, `symbol`,
#'   `timeframe`.
#'
#' @importFrom lubridate as_datetime now ddays
#' @importFrom rlang inform warn
#' @export
#'
#' @examples
#' \dontrun{
#' coinbase_backfill_klines(
#'   symbols = c("BTC-USD", "ETH-USD"),
#'   timeframes = c("1day", "1hour"),
#'   from = lubridate::as_datetime("2020-01-01"),
#'   file = "coinbase_klines.csv"
#' )
#' }
coinbase_backfill_klines <- function(
  symbols,
  timeframes = "1day",
  from = lubridate::now("UTC") - lubridate::ddays(365),
  to = lubridate::now("UTC"),
  file,
  base_url = get_base_url(),
  exchange_base_url = get_exchange_base_url(),
  max_bars = 300L,
  sleep = 0.3,
  verbose = TRUE
) {
  if (is.null(symbols) || length(symbols) == 0L) {
    abort_coinbase_validation_error("`symbols` must be a non-empty character vector.")
  }
  for (s in symbols) {
    validate_symbol(s)
  }
  if (missing(file) || !is.character(file) || length(file) != 1L || !nzchar(file)) {
    abort_coinbase_validation_error("`file` must be a single non-empty path string.")
  }
  if (is.null(timeframes) || length(timeframes) == 0L) {
    abort_coinbase_validation_error("`timeframes` must be a non-empty character vector.")
  }
  unknown <- setdiff(timeframes, names(.COINBASE_GRANULARITY_MAP))
  if (length(unknown) > 0L) {
    abort_coinbase_validation_error(paste0(
      "Invalid timeframe(s): ",
      paste(unknown, collapse = ", "),
      ". Valid: ",
      paste(names(.COINBASE_GRANULARITY_MAP), collapse = ", ")
    ))
  }
  assert_args_coinbase_backfill_klines(
    symbols,
    timeframes,
    from,
    to,
    base_url,
    exchange_base_url,
    max_bars,
    sleep,
    verbose
  )

  from <- lubridate::as_datetime(from, tz = "UTC")
  to <- lubridate::as_datetime(to, tz = "UTC")
  # One reference instant for the whole sweep, so the closed-candle trim is
  # consistent across every combination.
  now <- lubridate::now("UTC")

  # Public market data needs no credentials.
  client <- CoinbaseMarketData$new(
    keys = NULL,
    base_url = base_url,
    exchange_base_url = exchange_base_url,
    async = FALSE
  )

  # Resume support: continue each (symbol, timeframe) from its last stored candle.
  resume <- NULL
  if (file.exists(file)) {
    existing <- data.table::fread(file)
    if (nrow(existing) > 0L && all(c("symbol", "timeframe", "datetime") %in% names(existing))) {
      existing[, datetime := lubridate::as_datetime(datetime, tz = "UTC")]
      resume <- existing[, list(last_dt = max(datetime)), by = list(symbol, timeframe)]
    } else if (nrow(existing) > 0L) {
      abort_coinbase_validation_error(paste0(
        "Output file '",
        file,
        "' exists but lacks the required columns ",
        "(symbol, timeframe, datetime). Refusing to append; remove or fix the file."
      ))
    }
  }

  combos <- expand.grid(
    symbol = symbols,
    timeframe = timeframes,
    stringsAsFactors = FALSE
  )
  total <- nrow(combos)
  failures <- list()
  # Only append (skip the header) when a valid, non-empty file is being extended.
  wrote_any <- !is.null(resume)

  for (i in seq_len(total)) {
    sym <- combos$symbol[i]
    tf <- combos$timeframe[i]

    combo_from <- from
    last_dt <- NULL
    if (!is.null(resume)) {
      match_row <- resume[symbol == sym & timeframe == tf]
      if (nrow(match_row) > 0L) {
        last_dt <- match_row$last_dt[1L]
        if (last_dt >= to) {
          if (verbose) {
            rlang::inform(sprintf("[%d/%d] %s %s: skipped (already up to date)", i, total, sym, tf))
          }
          next
        }
        # Resume inclusively; the repeated boundary candle is collapsed below.
        combo_from <- last_dt
      }
    }

    dt <- tryCatch(
      coinbase_fetch_klines(
        product_id = sym,
        granularity = tf,
        from = combo_from,
        to = to,
        .fetch_window = function(start, end) {
          return(client$get_ohlcv(product_id = sym, granularity = tf, start = start, end = end))
        },
        max_bars = max_bars,
        sleep = sleep,
        now = now
      ),
      error = function(e) {
        failures[[length(failures) + 1L]] <<- data.table::data.table(
          symbol = sym,
          timeframe = tf,
          error = conditionMessage(e)
        )
        rlang::warn(sprintf("[%d/%d] %s %s: FAILED - %s", i, total, sym, tf, conditionMessage(e)))
        return(NULL)
      }
    )

    # Collapse the resume-boundary duplicate: the inclusive re-fetch repeats the
    # last stored candle, so keep only strictly-newer candles before appending.
    if (!is.null(dt) && !is.null(last_dt)) {
      dt <- dt[datetime > last_dt]
    }

    if (!is.null(dt) && nrow(dt) > 0L) {
      dt[, symbol := sym]
      dt[, timeframe := tf]
      data.table::setcolorder(dt, c("datetime", "open", "high", "low", "close", "volume", "symbol", "timeframe"))
      data.table::fwrite(dt, file, append = wrote_any)
      wrote_any <- TRUE

      if (verbose) {
        msg <- sprintf("[%d/%d] %s %s: %d candles", i, total, sym, tf, nrow(dt))
        if (!is.null(last_dt)) {
          msg <- paste0(msg, sprintf(" (resumed from %s)", format(last_dt, "%Y-%m-%d")))
        }
        rlang::inform(msg)
      }
    } else if (is.null(dt)) {
      # Error already handled above.
    } else {
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s %s: 0 candles", i, total, sym, tf))
      }
    }

    if (i < total && sleep > 0) {
      Sys.sleep(sleep)
    }
  }

  if (length(failures) > 0L) {
    failed_dt <- data.table::rbindlist(failures)
    pairs <- paste(
      sprintf("%s/%s", failed_dt$symbol, failed_dt$timeframe),
      collapse = ", "
    )
    rlang::warn(sprintf(
      "coinbase_backfill_klines: %d of %d (symbol, timeframe) combinations failed: %s",
      nrow(failed_dt),
      total,
      pairs
    ))
  }

  return(invisible(assert_return_coinbase_backfill_klines(file)))
}
