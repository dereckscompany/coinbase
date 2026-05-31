# Offline unit tests for pure helpers (no network).

test_that("verify_symbol accepts spot pairs and multi-segment futures IDs", {
  expect_true(verify_symbol("BTC-USD"))
  expect_true(verify_symbol("ETH-USD"))
  # CFM expiring-futures IDs have more than two segments.
  expect_true(verify_symbol("BIT-28FEB25-CDE"))
  expect_true(verify_symbol("ETH-26SEP25-CDE"))
  expect_false(verify_symbol("BTCUSD"))
  expect_false(verify_symbol("BTC_USD"))
  expect_false(verify_symbol("BTC-"))
  expect_false(verify_symbol(""))
})

test_that("as_dt_row never emits a list column (nested/multi-element collapse to JSON)", {
  # A flat object with a nested array AND a nested object must yield a single
  # row with zero list columns; the nested fields become scalar JSON strings.
  dt <- as_dt_row(list(
    id = "BTC-USD",
    status = "online",
    alias_to = list("BTC-USD-OLD", "BTC-USD-LEGACY"),
    details = list(session = "open", venue = "CDE")
  ))
  expect_equal(nrow(dt), 1L)
  expect_false(any(vapply(dt, is.list, logical(1))))
  expect_type(dt$alias_to, "character")
  expect_true(grepl("BTC-USD-OLD", dt$alias_to))
  expect_true(grepl("session", dt$details))
})

test_that("to_snake_case converts camelCase and leaves snake_case intact", {
  expect_equal(to_snake_case("productId"), "product_id")
  expect_equal(to_snake_case("bestBidAsk"), "best_bid_ask")
  expect_equal(to_snake_case("product_id"), "product_id")
})

test_that("parse_candles reorders to canonical OHLCV and sorts ascending", {
  # Exchange shape: [time, low, high, open, close, volume], newest first.
  raw <- list(
    list(200, 5, 15, 10, 12, 1.5),
    list(100, 4, 14, 9, 11, 2.5)
  )
  dt <- parse_candles(raw)
  expect_equal(names(dt), c("datetime", "open", "high", "low", "close", "volume"))
  expect_true(inherits(dt$datetime, "POSIXct"))
  # sorted ascending by time
  expect_equal(as.numeric(dt$datetime), c(100, 200))
  expect_equal(dt$open, c(9, 10))
  expect_equal(dt$high, c(14, 15))
  expect_equal(dt$low, c(4, 5))
  expect_equal(dt$close, c(11, 12))
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_trades coerces types and has no list columns", {
  raw <- list(
    list(trade_id = 2, side = "buy", size = "0.5", price = "100.5", time = "2026-01-01T00:00:01Z"),
    list(trade_id = 1, side = "sell", size = "1.0", price = "100.0", time = "2026-01-01T00:00:00Z")
  )
  dt <- parse_trades(raw)
  expect_equal(names(dt), c("trade_id", "side", "price", "size", "time"))
  expect_type(dt$price, "double")
  expect_type(dt$size, "double")
  expect_true(inherits(dt$time, "POSIXct"))
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_orderbook flattens bids/asks into a long table without list columns", {
  raw <- list(
    bids = list(list("100", "1.0", 2), list("99", "2.0", 1)),
    asks = list(list("101", "1.5", 3))
  )
  dt <- parse_orderbook(raw)
  expect_equal(names(dt), c("side", "price", "size", "num_orders"))
  expect_equal(nrow(dt), 3L)
  expect_equal(dt[side == "ask"]$price, 101)
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("trades_to_ohlcv aggregates ticks into bars", {
  trades <- data.table::data.table(
    trade_id = 1:4,
    side = c("buy", "sell", "buy", "sell"),
    price = c(10, 12, 11, 20),
    size = c(1, 1, 2, 3),
    # two trades in the first minute, two in the second
    time = lubridate::as_datetime(c(0, 30, 60, 90), tz = "UTC")
  )
  bars <- trades_to_ohlcv(trades, interval = 60)
  expect_equal(names(bars), c("datetime", "open", "high", "low", "close", "volume"))
  expect_equal(nrow(bars), 2L)
  # first bar: trades at t=0,30 -> open 10, high 12, low 10, close 12, vol 2
  expect_equal(bars$open, c(10, 11))
  expect_equal(bars$high, c(12, 20))
  expect_equal(bars$low, c(10, 11))
  expect_equal(bars$close, c(12, 20))
  expect_equal(bars$volume, c(2, 5))
  expect_false(any(vapply(bars, is.list, logical(1))))
})

test_that("trades_to_ohlcv returns an empty data.table for empty input", {
  empty <- data.table::data.table(
    trade_id = numeric(0),
    side = character(0),
    price = numeric(0),
    size = numeric(0),
    time = lubridate::as_datetime(numeric(0))
  )
  expect_equal(nrow(trades_to_ohlcv(empty)), 0L)
})
