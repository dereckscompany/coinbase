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
  expect_true(all(c("symbol", "trade_id", "side", "price", "size", "time") %in% names(d1)))
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
