# Offline tests for the write-path parsers — these guard the no-list-column
# invariant that the review found broken on add_order/edit/cancel/margin-window.

no_list <- function(dt) !any(vapply(dt, is.list, logical(1)))

test_that("collapse_errors handles objects, strings, and NULL", {
  expect_true(is.na(collapse_errors(NULL)))
  expect_true(is.na(collapse_errors(list())))
  expect_equal(collapse_errors(list("A", "B")), "A; B")
  expect_equal(
    collapse_errors(list(list(error_code = "INSUFFICIENT_FUND", message = "x"))),
    "INSUFFICIENT_FUND"
  )
  expect_equal(
    collapse_errors(list(list(message = "only message"))),
    "only message"
  )
})

test_that("parse_create_order surfaces order_id and has no list columns", {
  resp <- list(
    success = TRUE,
    success_response = list(order_id = "o-123", product_id = "BTC-USD", side = "BUY", client_order_id = "c1"),
    order_configuration = list(market_market_ioc = list(quote_size = "10"))
  )
  dt <- parse_create_order(resp)
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$order_id, "o-123")
  expect_equal(dt$product_id, "BTC-USD")
  expect_equal(dt$config_type, "market_market_ioc")
  expect_equal(dt$quote_size, 10)
  expect_true(dt$success)
  expect_true(no_list(dt))
})

test_that("parse_create_order collapses failure/error objects to a string", {
  resp <- list(
    success = FALSE,
    error_response = list(error = "INVALID_LIMIT_PRICE", message = "bad price"),
    order_configuration = list(limit_limit_gtc = list(base_size = "1", limit_price = "5"))
  )
  dt <- parse_create_order(resp)
  expect_false(dt$success)
  expect_equal(dt$failure_reason, "INVALID_LIMIT_PRICE")
  expect_true(no_list(dt))
})

test_that("parse_edit_order / parse_edit_preview have no list columns", {
  e <- parse_edit_order(list(
    success = TRUE,
    success_response = list(order_id = "o1"),
    errors = list(list(error_code = "X"))
  ))
  expect_equal(e$order_id, "o1")
  expect_equal(e$errors, "X")
  expect_true(no_list(e))

  p <- parse_edit_preview(list(
    errors = list(list(error_code = "Y")),
    order_total = "10",
    slippage = "0.001",
    base_size = "0.1"
  ))
  expect_equal(p$errors, "Y")
  expect_equal(p$order_total, 10)
  expect_true(no_list(p))
})

test_that("parse_cancel_results flattens per-order results with no list columns", {
  dt <- parse_cancel_results(list(
    list(order_id = "o1", success = TRUE, failure_reason = "UNKNOWN_CANCEL_FAILURE_REASON"),
    list(order_id = "o2", success = FALSE, failure_reason = list(error = "NOT_FOUND"))
  ))
  expect_equal(nrow(dt), 2L)
  expect_equal(dt$order_id, c("o1", "o2"))
  expect_equal(dt$failure_reason[2], "NOT_FOUND")
  expect_true(no_list(dt))
})

test_that("parse_margin_window flattens the nested margin_window object", {
  dt <- parse_margin_window(list(
    margin_window = list(margin_window_type = "INTRADAY", end_time = "2026-01-01T00:00:00Z"),
    is_intraday_margin_killswitch_enabled = FALSE
  ))
  expect_equal(dt$margin_window_type, "INTRADAY")
  expect_true(inherits(dt$end_time, "POSIXct"))
  expect_false(dt$is_intraday_margin_killswitch_enabled)
  expect_true(no_list(dt))
})

test_that("flatten_order_config captures stop_trigger_price for bracket orders", {
  cfg <- list(trigger_bracket_gtc = list(base_size = "1", limit_price = "100", stop_trigger_price = "90"))
  f <- flatten_order_config(cfg)
  expect_equal(f$config_type, "trigger_bracket_gtc")
  expect_equal(f$stop_trigger_price, 90)
  expect_true(is.na(f$stop_price))
  # surfaced through parse_orders too
  dt <- parse_orders(list(list(order_id = "o1", order_configuration = cfg)))
  expect_equal(dt$stop_trigger_price, 90)
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_orderbook emits order_id (string) at level 3, num_orders otherwise", {
  raw <- list(
    bids = list(list("100", "1.0", "11111111-1111-1111-1111-111111111111")),
    asks = list(list("101", "2.0", "22222222-2222-2222-2222-222222222222"))
  )
  l3 <- parse_orderbook(raw, level = 3L)
  expect_true("order_id" %in% names(l3))
  expect_false("num_orders" %in% names(l3))
  expect_equal(l3$order_id[1], "11111111-1111-1111-1111-111111111111")
  expect_type(l3$order_id, "character")
  expect_false(any(vapply(l3, is.list, logical(1))))

  raw2 <- list(bids = list(list("100", "1.0", 5)), asks = list(list("101", "2.0", 3)))
  l2 <- parse_orderbook(raw2, level = 2L)
  expect_true("num_orders" %in% names(l2))
  expect_equal(l2$num_orders[1], 5)
})

test_that("single-item parsers return an empty table for a NULL inner object", {
  # get_order(list(b$order)) with b$order NULL -> must NOT fabricate an NA row
  expect_equal(nrow(parse_orders(list(NULL))), 0L)
  expect_equal(nrow(parse_accounts(list(NULL))), 0L)
  expect_equal(nrow(parse_futures_positions(list(NULL))), 0L)
})
