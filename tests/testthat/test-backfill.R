# Live-guarded test for coinbase_backfill_trades. It only reads PUBLIC trade
# data and writes a local CSV (no auth, no orders), so it is safe to run, but it
# needs network — skipped on CRAN / when offline.

test_that("coinbase_backfill_trades writes a header, resumes, and never duplicates trade_ids", {
  testthat::skip_on_cran()
  testthat::skip_if_offline("api.exchange.coinbase.com")

  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  start <- lubridate::now("UTC") - lubridate::dminutes(1)

  coinbase_backfill_trades("BTC-USD", from = start, file = f, sleep = 0, verbose = FALSE)
  d1 <- data.table::fread(f)
  expect_true(all(c("symbol", "trade_id", "side", "price", "size", "timestamp") %in% names(d1)))
  expect_gt(nrow(d1), 0L)

  # Resume WITH a finite max_pages: exercises the gap-avoidance branch (max_pages
  # is ignored on resume) and must not duplicate or error.
  coinbase_backfill_trades("BTC-USD", from = start, file = f, max_pages = 1, sleep = 0, verbose = FALSE)
  d2 <- data.table::fread(f)
  expect_gte(nrow(d2), nrow(d1))
  expect_equal(sum(duplicated(d2$trade_id)), 0L)
})

test_that("coinbase_backfill_trades validates symbols and refuses a malformed existing file", {
  expect_error(coinbase_backfill_trades("BTCUSD", file = tempfile()), "Invalid product_id")

  bad <- tempfile(fileext = ".csv")
  on.exit(unlink(bad), add = TRUE)
  writeLines(c("a,b", "1,2"), bad)
  expect_error(
    coinbase_backfill_trades("BTC-USD", file = bad),
    "required columns"
  )
})

# -- coinbase_backfill_klines (HTTP-mocked, no network) -----------------------

# Build a Coinbase Exchange /candles response body for the aligned candle open
# times in [start_s, end_s] (each row is [time, low, high, open, close, volume],
# most-recent-first, as the real endpoint returns).
.candles_body <- function(start_s, end_s, step_s) {
  times <- rev(seq(start_s, end_s, by = step_s))
  rows <- vapply(
    times,
    function(t) sprintf("[%.0f,100.0,110.0,105.0,106.0,1.5]", t),
    character(1L)
  )
  return(paste0("[", paste(rows, collapse = ","), "]"))
}

# A URL-aware mock: read granularity/start/end off the request query and serve
# exactly that window's candles, so a multi-window backfill is stitched from
# genuinely distinct pages.
.mock_candles_by_window <- function(req) {
  q <- httr2::url_parse(req$url)$query
  body <- .candles_body(as.numeric(q$start), as.numeric(q$end), as.numeric(q$granularity))
  return(httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(body)
  ))
}

test_that("coinbase_backfill_klines stitches windows and writes symbol/timeframe columns", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  httr2::local_mocked_responses(.mock_candles_by_window)

  # 4-day span at max_bars = 2 forces 3 windows (Jan1-2, Jan3-4, Jan5).
  coinbase_backfill_klines(
    symbols = "BTC-USD",
    timeframes = "1day",
    from = lubridate::as_datetime("2024-01-01", tz = "UTC"),
    to = lubridate::as_datetime("2024-01-05", tz = "UTC"),
    file = f,
    max_bars = 2L,
    sleep = 0,
    verbose = FALSE
  )

  d <- data.table::fread(f)
  expect_true(all(
    c("datetime", "open", "high", "low", "close", "volume", "symbol", "timeframe") %in% names(d)
  ))
  expect_equal(unique(d$symbol), "BTC-USD")
  expect_equal(unique(d$timeframe), "1day")
  expect_equal(nrow(d), 5L) # Jan1..Jan5, all closed
  expect_equal(sum(duplicated(d$datetime)), 0L)
})

test_that("coinbase_backfill_klines resumes inclusively and collapses the boundary duplicate", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)

  existing <- data.table::data.table(
    datetime = lubridate::as_datetime(c("2024-01-02", "2024-01-03"), tz = "UTC"),
    open = c(1, 2),
    high = c(1, 2),
    low = c(1, 2),
    close = c(1, 2),
    volume = c(1, 2),
    symbol = "BTC-USD",
    timeframe = "1day"
  )
  data.table::fwrite(existing, f)

  httr2::local_mocked_responses(.mock_candles_by_window)

  coinbase_backfill_klines(
    symbols = "BTC-USD",
    timeframes = "1day",
    from = lubridate::as_datetime("2024-01-01", tz = "UTC"),
    to = lubridate::as_datetime("2024-01-06", tz = "UTC"),
    file = f,
    max_bars = 300L,
    sleep = 0,
    verbose = FALSE
  )

  d <- data.table::fread(f)
  d[, datetime := lubridate::as_datetime(datetime, tz = "UTC")]
  jan3 <- as.numeric(lubridate::as_datetime("2024-01-03", tz = "UTC"))
  jan4 <- as.numeric(lubridate::as_datetime("2024-01-04", tz = "UTC"))

  # The resume boundary (Jan3) appears exactly once; newer candles are appended.
  expect_equal(sum(as.numeric(d$datetime) == jan3), 1L)
  expect_equal(sum(duplicated(d$datetime)), 0L)
  expect_true(jan4 %in% as.numeric(d$datetime))
})

test_that("coinbase_backfill_klines skips a combo whose last stored candle reaches `to`", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)

  existing <- data.table::data.table(
    datetime = lubridate::as_datetime("2024-01-05", tz = "UTC"),
    open = 1,
    high = 1,
    low = 1,
    close = 1,
    volume = 1,
    symbol = "BTC-USD",
    timeframe = "1day"
  )
  data.table::fwrite(existing, f)

  called <- FALSE
  httr2::local_mocked_responses(function(req) {
    called <<- TRUE
    return(.mock_candles_by_window(req))
  })

  coinbase_backfill_klines(
    symbols = "BTC-USD",
    timeframes = "1day",
    from = lubridate::as_datetime("2024-01-01", tz = "UTC"),
    to = lubridate::as_datetime("2024-01-04", tz = "UTC"),
    file = f,
    sleep = 0,
    verbose = FALSE
  )

  expect_false(called) # already up to date, no request made
})

test_that("coinbase_backfill_klines validates symbols, timeframes, and a malformed file", {
  expect_error(coinbase_backfill_klines(NULL, file = tempfile()), "non-empty")
  expect_error(coinbase_backfill_klines(character(0), file = tempfile()), "non-empty")
  expect_error(coinbase_backfill_klines("BTCUSD", file = tempfile()), "Invalid product_id")
  expect_error(
    coinbase_backfill_klines("BTC-USD", timeframes = "2min", file = tempfile()),
    "Invalid timeframe"
  )

  bad <- tempfile(fileext = ".csv")
  on.exit(unlink(bad), add = TRUE)
  writeLines(c("a,b", "1,2"), bad)
  expect_error(coinbase_backfill_klines("BTC-USD", file = bad), "required columns")
})

test_that("coinbase_backfill_klines warns per failed combo and emits a final summary", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)

  # A 400 aborts immediately (non-retryable), so the combo fails fast.
  httr2::local_mocked_responses(function(req) {
    return(httr2::response(
      status_code = 400L,
      headers = list(`Content-Type` = "application/json"),
      body = charToRaw('{"message":"boom"}')
    ))
  })

  seen <- character(0)
  res <- withCallingHandlers(
    coinbase_backfill_klines(
      symbols = "BTC-USD",
      timeframes = "1day",
      from = lubridate::as_datetime("2024-01-01", tz = "UTC"),
      to = lubridate::as_datetime("2024-01-03", tz = "UTC"),
      file = f,
      sleep = 0,
      verbose = FALSE
    ),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  expect_true(any(grepl("BTC-USD", seen) & grepl("FAILED", seen)))
  expect_true(any(grepl("1 of 1", seen) & grepl("BTC-USD/1day", seen)))
  expect_type(res, "character")
  expect_null(attr(res, "failures"))
})
