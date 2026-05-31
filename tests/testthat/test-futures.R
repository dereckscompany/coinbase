# Offline tests for the futures (CFM) parsers.

test_that("flex_num handles scalars, {value} objects, and NULL", {
  expect_equal(flex_num("1.5"), 1.5)
  expect_equal(flex_num(list(value = "2.5", currency = "USD")), 2.5)
  expect_true(is.na(flex_num(NULL)))
})

test_that("parse_futures_balance flattens nested amounts with no list columns", {
  data <- list(
    futures_buying_power = list(value = "1000", currency = "USD"),
    total_usd_balance = list(value = "1200", currency = "USD"),
    cbi_usd_balance = list(value = "200", currency = "USD"),
    cfm_usd_balance = list(value = "1000", currency = "USD"),
    unrealized_pnl = list(value = "-5", currency = "USD"),
    liquidation_buffer_percentage = "12.5"
  )
  dt <- parse_futures_balance(data)
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$futures_buying_power, 1000)
  expect_equal(dt$unrealized_pnl, -5)
  expect_equal(dt$liquidation_buffer_percentage, 12.5)
  expect_false(any(vapply(dt, is.list, logical(1))))
  expect_equal(nrow(parse_futures_balance(NULL)), 0L)
})

test_that("parse_futures_positions flattens with no list columns", {
  items <- list(
    list(
      product_id = "BIT-28FEB25-CDE",
      side = "SHORT",
      number_of_contracts = "2",
      current_price = list(value = "95000", currency = "USD"),
      avg_entry_price = list(value = "96000", currency = "USD"),
      unrealized_pnl = list(value = "2000", currency = "USD"),
      expiration_time = "2026-02-28T00:00:00Z"
    )
  )
  dt <- parse_futures_positions(items)
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$side, "SHORT")
  expect_equal(dt$number_of_contracts, 2)
  expect_equal(dt$avg_entry_price, 96000)
  expect_true(inherits(dt$expiration_time, "POSIXct"))
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_futures_sweeps flattens requested_amount", {
  items <- list(
    list(
      id = "s1",
      requested_amount = list(value = "500", currency = "USD"),
      should_sweep_all = FALSE,
      status = "PENDING",
      schedule_time = "2026-01-01T00:00:00Z"
    )
  )
  dt <- parse_futures_sweeps(items)
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$requested_amount, 500)
  expect_equal(dt$status, "PENDING")
  expect_false(any(vapply(dt, is.list, logical(1))))
})
