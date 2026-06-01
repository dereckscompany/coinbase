# End-to-end tests: drive every public R6 client method through the shared
# mock_router (the same fixtures the README and vignettes render against). Unit
# tests exercise the parsers in isolation; these cover the wiring around them —
# endpoint strings, query/host/auth selection, pagination, and each method's
# .parser closure — which otherwise only runs during a docs render.

box::use(./mock_router[mock_router])

# A throwaway EC P-256 key so JWT signing (which runs before the request)
# succeeds; the mock ignores the Authorization header entirely.
.sk <- openssl::ec_keygen("P-256")
.keys <- list(
  api_key_name = "organizations/o/apiKeys/k",
  api_private_key = openssl::write_pem(.sk)
)

test_that("CoinbaseMarketData public methods round-trip through the router", {
  old <- options(httr2_mock = mock_router)
  on.exit(options(old), add = TRUE)
  market <- CoinbaseMarketData$new(keys = .keys)

  expect_true(data.table::is.data.table(market$get_products()))
  expect_equal(nrow(market$get_product("BTC-USD")), 1L)

  ohlcv <- market$get_ohlcv("BTC-USD", granularity = "1day")
  expect_true(all(c("datetime", "open", "high", "low", "close", "volume") %in% names(ohlcv)))

  trades <- market$get_trades("BTC-USD")
  expect_true(all(c("trade_id", "side", "price", "size", "time") %in% names(trades)))

  # Drives the (now iterative) synchronous paginator end-to-end.
  hist <- market$get_trades_history("BTC-USD", max_pages = 1)
  expect_true(data.table::is.data.table(hist))

  book <- market$get_orderbook("BTC-USD")
  expect_true(all(c("side", "price", "size") %in% names(book)))

  ticker <- market$get_ticker("BTC-USD")
  expect_true(is.numeric(ticker$price))

  expect_true("product_id" %in% names(market$get_stats()))
  expect_equal(nrow(market$get_product_stats("BTC-USD")), 1L)
  expect_true(
    inherits(market$get_server_time()$datetime, "POSIXct") ||
      data.table::is.data.table(market$get_server_time())
  )

  # The sole auth=TRUE market-data method (Advanced Trade host).
  bba <- market$get_best_bid_ask()
  expect_true(all(c("product_id", "bid_price", "ask_price") %in% names(bba)))
})

test_that("CoinbaseAccount public methods round-trip through the router", {
  old <- options(httr2_mock = mock_router)
  on.exit(options(old), add = TRUE)
  account <- CoinbaseAccount$new(keys = .keys)

  expect_true(data.table::is.data.table(account$get_accounts(max_pages = 1)))
  expect_equal(nrow(account$get_account("a-uuid")), 1L)
  expect_equal(nrow(account$get_fees()), 1L)
  expect_true(data.table::is.data.table(account$get_portfolios()))
  expect_equal(nrow(account$get_key_permissions()), 1L)

  # fid-1 end-to-end: stacked positions + separate one-row summary, same endpoint.
  pos <- account$get_portfolio_breakdown("p-uuid")
  expect_true("position_type" %in% names(pos))
  expect_setequal(unique(pos$position_type), c("spot", "futures", "perp"))
  expect_true(all(c("entry_price", "mark_price", "side", "unrealized_pnl") %in% names(pos)))
  expect_false(any(vapply(pos, is.list, logical(1))))

  summ <- account$get_portfolio_summary("p-uuid")
  expect_equal(nrow(summ), 1L)
  expect_true(all(c("total_balance", "futures_unrealized_pnl", "perp_unrealized_pnl") %in% names(summ)))
  expect_false(any(vapply(summ, is.list, logical(1))))
})

test_that("CoinbaseTrading public methods round-trip through the router", {
  old <- options(httr2_mock = mock_router)
  on.exit(options(old), add = TRUE)
  trading <- CoinbaseTrading$new(keys = .keys)
  cfg <- list(market_market_ioc = list(quote_size = "10"))

  expect_true(data.table::is.data.table(trading$add_order("BTC-USD", "BUY", cfg)))
  expect_true(data.table::is.data.table(trading$preview_order("BTC-USD", "BUY", cfg)))
  expect_equal(nrow(trading$get_order("o-1")), 1L)
  expect_true(data.table::is.data.table(trading$get_orders(max_pages = 1)))
  expect_true(data.table::is.data.table(trading$get_fills(max_pages = 1)))
  expect_true(data.table::is.data.table(trading$edit_order("o-1", price = "30000")))
  expect_true(data.table::is.data.table(trading$preview_edit_order("o-1", price = "30000")))
  expect_true(data.table::is.data.table(trading$cancel_orders(c("o-1", "o-2"))))
  expect_true(data.table::is.data.table(trading$close_position("BTC-USD")))
})

test_that("CoinbaseFutures public methods round-trip through the router", {
  old <- options(httr2_mock = mock_router)
  on.exit(options(old), add = TRUE)
  futures <- CoinbaseFutures$new(keys = .keys)

  expect_equal(nrow(futures$get_balance_summary()), 1L)
  expect_true(data.table::is.data.table(futures$get_positions()))
  expect_equal(nrow(futures$get_position("BIT-28FEB26-CDE")), 1L)
  expect_true(data.table::is.data.table(futures$get_sweeps()))
  expect_true(data.table::is.data.table(futures$schedule_sweep(100)))
  expect_true(data.table::is.data.table(futures$cancel_sweep()))
  expect_true(data.table::is.data.table(futures$get_intraday_margin_setting()))
  expect_true(data.table::is.data.table(futures$set_intraday_margin_setting("INTRADAY")))
  expect_equal(nrow(futures$get_current_margin_window("MARGIN_PROFILE_TYPE_RETAIL_INTRADAY_MARGIN_1")), 1L)
})
