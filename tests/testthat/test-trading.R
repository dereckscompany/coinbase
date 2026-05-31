# Offline tests for trading parsers and the client-order-id generator.

test_that("generate_client_order_id produces a v4 UUID", {
  id <- generate_client_order_id()
  expect_match(id, "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
  expect_false(identical(generate_client_order_id(), generate_client_order_id()))
})

test_that("flatten_order_config extracts the type key and sub-fields", {
  cfg <- list(limit_limit_gtc = list(base_size = "0.001", limit_price = "50000", post_only = TRUE))
  f <- flatten_order_config(cfg)
  expect_equal(f$config_type, "limit_limit_gtc")
  expect_equal(f$base_size, 0.001)
  expect_equal(f$limit_price, 50000)
  expect_true(f$post_only)
  expect_true(is.na(f$stop_price))
  # NULL config -> all NA
  empty <- flatten_order_config(NULL)
  expect_true(is.na(empty$config_type))
})

test_that("parse_orders flattens config into columns with no list columns", {
  items <- list(
    list(
      order_id = "o1",
      client_order_id = "c1",
      product_id = "BTC-USD",
      side = "BUY",
      status = "FILLED",
      time_in_force = "GTC",
      created_time = "2026-01-01T00:00:00Z",
      completion_percentage = "100",
      filled_size = "0.001",
      average_filled_price = "50000",
      number_of_fills = "1",
      filled_value = "50",
      total_fees = "0.3",
      order_configuration = list(limit_limit_gtc = list(base_size = "0.001", limit_price = "50000"))
    ),
    list(
      order_id = "o2",
      product_id = "ETH-USD",
      side = "SELL",
      status = "OPEN",
      order_configuration = list(market_market_ioc = list(quote_size = "25"))
    )
  )
  dt <- parse_orders(items)
  expect_equal(nrow(dt), 2L)
  expect_true(all(
    c("order_id", "product_id", "side", "status", "config_type", "limit_price", "base_size", "quote_size") %in%
      names(dt)
  ))
  expect_equal(dt$config_type, c("limit_limit_gtc", "market_market_ioc"))
  expect_equal(dt$limit_price, c(50000, NA))
  expect_equal(dt$quote_size, c(NA, 25))
  expect_true(inherits(dt$created_time, "POSIXct"))
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_fills coerces types with no list columns", {
  items <- list(
    list(
      entry_id = "e1",
      trade_id = "t1",
      order_id = "o1",
      product_id = "BTC-USD",
      side = "BUY",
      trade_time = "2026-01-01T00:00:00Z",
      trade_type = "FILL",
      price = "50000",
      size = "0.001",
      commission = "0.3",
      liquidity_indicator = "MAKER"
    )
  )
  dt <- parse_fills(items)
  expect_equal(nrow(dt), 1L)
  expect_type(dt$price, "double")
  expect_equal(dt$commission, 0.3)
  expect_true(inherits(dt$trade_time, "POSIXct"))
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_preview flattens result and joins error list to a string", {
  data <- list(
    order_total = "10",
    commission_total = "0.118",
    quote_size = "9.88",
    base_size = "0.00013",
    best_bid = "73900",
    best_ask = "73901",
    slippage = "0.0001",
    errs = list("PREVIEW_INSUFFICIENT_FUND"),
    preview_id = "p1"
  )
  dt <- parse_preview(data)
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$order_total, 10)
  expect_equal(dt$errs, "PREVIEW_INSUFFICIENT_FUND")
  expect_false(any(vapply(dt, is.list, logical(1))))
  # no errors -> NA
  ok <- parse_preview(list(order_total = "10", errs = list()))
  expect_true(is.na(ok$errs))
})
