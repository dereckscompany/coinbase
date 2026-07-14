# tests/testthat/test-impl_klines.R
# Deterministic, offline tests for the shared window-pagination core
# (coinbase_candle_windows / coinbase_fetch_klines). The fetch is driven with an
# injected .fetch_window() callback so multi-window stitching, dedup, and the
# closed-candle trim are exercised without any network.

# A small Ohlcv fabricator: one row per candle open-time (epoch seconds).
mk_ohlcv <- function(times_s) {
  n <- length(times_s)
  return(data.table::data.table(
    datetime = lubridate::as_datetime(times_s, tz = "UTC"),
    open = as.numeric(seq_len(n)),
    high = as.numeric(seq_len(n)) + 1,
    low = as.numeric(seq_len(n)) - 1,
    close = as.numeric(seq_len(n)) + 0.5,
    volume = as.numeric(seq_len(n))
  ))
}

# -- coinbase_candle_windows --

test_that("coinbase_candle_windows tiles a range into non-overlapping <=max_bars windows", {
  step <- 60
  from_s <- 1000000
  to_s <- from_s + 11 * step # 12 candle slots

  w <- coinbase_candle_windows(from_s, to_s, step, max_bars = 5L)

  # span per window = (5 - 1) * 60 = 240s
  expect_equal(length(w), 3L)
  expect_equal(w[[1]]$start, from_s)
  expect_equal(w[[1]]$end, from_s + 240)
  expect_equal(w[[2]]$start, from_s + 300)
  expect_equal(w[[2]]$end, from_s + 540)
  expect_equal(w[[3]]$start, from_s + 600)
  expect_equal(w[[3]]$end, to_s) # last window clamped to to_s

  # Each window starts exactly one step past the previous end: no overlap, no gap.
  expect_equal(w[[2]]$start, w[[1]]$end + step)
  expect_equal(w[[3]]$start, w[[2]]$end + step)
})

test_that("coinbase_candle_windows is empty for an inverted range", {
  expect_equal(length(coinbase_candle_windows(2000, 1000, 60, 5L)), 0L)
})

test_that("coinbase_candle_windows does day-granularity math in double past 2038 (no int32 overflow)", {
  step <- 86400
  from_s <- as.numeric(lubridate::as_datetime("2040-01-01", tz = "UTC"))
  to_s <- from_s + 500 * step

  expect_no_warning(w <- coinbase_candle_windows(from_s, to_s, step, max_bars = 300L))

  expect_gte(length(w), 2L)
  expect_false(any(vapply(w, function(x) is.na(x$end), logical(1L))))
  # These epochs sit past .Machine$integer.max; only double math survives them.
  expect_true(all(vapply(w, function(x) x$end > .Machine$integer.max, logical(1L))))
})

# -- coinbase_fetch_klines --

test_that("coinbase_fetch_klines stitches multiple windows, dedups, and sorts ascending", {
  step <- 60
  from_dt <- lubridate::as_datetime("2024-01-01 00:00:00", tz = "UTC")
  from_s <- as.numeric(from_dt)
  to_dt <- lubridate::as_datetime(from_s + 7 * step, tz = "UTC")

  windows_seen <- 0L
  fetch_window <- function(start, end) {
    windows_seen <<- windows_seen + 1L
    times <- seq(as.numeric(start), as.numeric(end), by = step)
    return(mk_ohlcv(times))
  }

  # A now far past the candles => everything is closed and kept.
  now_ref <- lubridate::as_datetime("2024-06-01", tz = "UTC")
  res <- coinbase_fetch_klines(
    product_id = "BTC-USD",
    granularity = "1min",
    from = from_dt,
    to = to_dt,
    .fetch_window = fetch_window,
    max_bars = 5L,
    now = now_ref
  )

  expect_gte(windows_seen, 2L)
  expect_equal(nrow(res), 8L)
  expect_equal(as.numeric(res$datetime), seq(from_s, from_s + 7 * step, by = step))
  expect_false(is.unsorted(as.numeric(res$datetime)))
})

test_that("coinbase_fetch_klines collapses overlapping datetimes across windows", {
  step <- 60
  from_dt <- lubridate::as_datetime("2024-01-01 00:00:00", tz = "UTC")
  from_s <- as.numeric(from_dt)
  to_dt <- lubridate::as_datetime(from_s + 6 * step, tz = "UTC")

  # Every window returns the SAME three candle times: the union must dedup to 3.
  fetch_window <- function(start, end) {
    return(mk_ohlcv(c(from_s, from_s + step, from_s + 2 * step)))
  }

  res <- coinbase_fetch_klines(
    product_id = "BTC-USD",
    granularity = "1min",
    from = from_dt,
    to = to_dt,
    .fetch_window = fetch_window,
    max_bars = 3L,
    now = lubridate::as_datetime("2024-06-01", tz = "UTC")
  )

  expect_equal(nrow(res), 3L)
  expect_equal(sum(duplicated(res$datetime)), 0L)
})

test_that("coinbase_fetch_klines drops the still-forming live-edge candle", {
  step <- 3600 # 1hour
  from_dt <- lubridate::as_datetime("2024-01-01 00:00:00", tz = "UTC")
  from_s <- as.numeric(from_dt)
  to_dt <- lubridate::as_datetime(from_s + 2 * step, tz = "UTC")

  fetch_window <- function(start, end) {
    return(mk_ohlcv(seq(as.numeric(start), as.numeric(end), by = step)))
  }

  # now sits 100s into the candle that opened at from_s + 2*step, so that bar is
  # still forming (closes at from_s + 3*step) and must be dropped.
  now_ref <- lubridate::as_datetime(from_s + 2 * step + 100, tz = "UTC")
  res <- coinbase_fetch_klines(
    product_id = "BTC-USD",
    granularity = "1hour",
    from = from_dt,
    to = to_dt,
    .fetch_window = fetch_window,
    max_bars = 300L,
    now = now_ref
  )

  expect_equal(as.numeric(res$datetime), c(from_s, from_s + step))
  expect_false((from_s + 2 * step) %in% as.numeric(res$datetime))
})

test_that("coinbase_fetch_klines returns the typed empty table when windows yield nothing", {
  fetch_window <- function(start, end) empty_dt_ohlcv()

  res <- coinbase_fetch_klines(
    product_id = "BTC-USD",
    granularity = "1day",
    from = lubridate::as_datetime("2024-01-01", tz = "UTC"),
    to = lubridate::as_datetime("2024-02-01", tz = "UTC"),
    .fetch_window = fetch_window
  )

  expect_s3_class(res, "data.table")
  expect_equal(nrow(res), 0L)
  expect_equal(names(res), c("datetime", "open", "high", "low", "close", "volume"))
})

test_that("coinbase_fetch_klines returns empty (and never fetches) for an inverted range", {
  called <- FALSE
  fetch_window <- function(start, end) {
    called <<- TRUE
    return(empty_dt_ohlcv())
  }

  res <- coinbase_fetch_klines(
    product_id = "BTC-USD",
    granularity = "1day",
    from = lubridate::as_datetime("2024-02-01", tz = "UTC"),
    to = lubridate::as_datetime("2024-01-01", tz = "UTC"),
    .fetch_window = fetch_window
  )

  expect_equal(nrow(res), 0L)
  expect_false(called)
})

test_that("coinbase_fetch_klines rejects an invalid granularity", {
  fetch_window <- function(start, end) stop("should not be called")
  expect_error(
    coinbase_fetch_klines(
      product_id = "BTC-USD",
      granularity = "2min",
      from = lubridate::as_datetime("2024-01-01", tz = "UTC"),
      to = lubridate::as_datetime("2024-01-02", tz = "UTC"),
      .fetch_window = fetch_window
    ),
    "Invalid granularity.*2min"
  )
})
