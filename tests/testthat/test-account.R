# Offline tests for account parsers and the body-cursor paginator.

test_that("parse_accounts flattens {value,currency} and has no list columns", {
  items <- list(
    list(
      uuid = "u1",
      name = "BTC Wallet",
      currency = "BTC",
      available_balance = list(value = "1.5", currency = "BTC"),
      hold = list(value = "0.25", currency = "BTC"),
      active = TRUE,
      default = TRUE,
      ready = TRUE,
      type = "ACCOUNT_TYPE_CRYPTO",
      platform = "ACCOUNT_PLATFORM_CONSUMER",
      retail_portfolio_id = "p1",
      created_at = "2025-01-01T00:00:00Z",
      updated_at = "2025-02-01T00:00:00Z"
    ),
    list(
      uuid = "u2",
      name = "USD Wallet",
      currency = "USD",
      available_balance = list(value = "100", currency = "USD"),
      hold = list(value = "0", currency = "USD"),
      active = TRUE,
      default = FALSE,
      ready = TRUE,
      type = "ACCOUNT_TYPE_FIAT",
      platform = "ACCOUNT_PLATFORM_CONSUMER",
      retail_portfolio_id = "p1",
      created_at = "2025-01-01T00:00:00Z",
      updated_at = "2025-02-01T00:00:00Z"
    )
  )
  dt <- parse_accounts(items)
  expect_equal(nrow(dt), 2L)
  expect_true(all(c("uuid", "currency", "available_balance", "hold") %in% names(dt)))
  expect_type(dt$available_balance, "double")
  expect_equal(dt$available_balance, c(1.5, 100))
  expect_equal(dt$hold, c(0.25, 0))
  expect_true(inherits(dt$created_at, "POSIXct"))
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_accounts handles NULL fields and empty input", {
  expect_equal(nrow(parse_accounts(NULL)), 0L)
  one <- parse_accounts(list(list(uuid = "u", currency = "BTC")))
  expect_equal(nrow(one), 1L)
  expect_true(is.na(one$available_balance))
  expect_true(is.na(one$name))
})

test_that("parse_fees flattens the fee_tier into scalar columns", {
  data <- list(
    total_volume = 1234.5,
    total_fees = 6.7,
    total_balance = "89.0",
    fee_tier = list(
      pricing_tier = "Intro 1",
      maker_fee_rate = "0.006",
      taker_fee_rate = "0.012",
      usd_from = "0",
      usd_to = "1000"
    )
  )
  dt <- parse_fees(data)
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$pricing_tier, "Intro 1")
  expect_equal(dt$maker_fee_rate, 0.006)
  expect_equal(dt$taker_fee_rate, 0.012)
  expect_equal(dt$total_balance, 89.0)
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("coinbase_paginate_cursor walks pages until has_next is false", {
  # Three pages of two items each; cursor advances, has_next flips on last page.
  pages <- list(
    list(accounts = list(list(uuid = "1"), list(uuid = "2")), has_next = TRUE, cursor = "c1"),
    list(accounts = list(list(uuid = "3"), list(uuid = "4")), has_next = TRUE, cursor = "c2"),
    list(accounts = list(list(uuid = "5")), has_next = FALSE, cursor = "")
  )
  calls <- 0
  req_fn <- function(endpoint, query) {
    # page selected by incoming cursor
    idx <- if (is.null(query$cursor)) 1L else as.integer(sub("c", "", query$cursor)) + 1L
    calls <<- calls + 1L
    return(pages[[idx]])
  }
  res <- coinbase_paginate_cursor(
    endpoint = "/x",
    items_field = "accounts",
    .req_fn = req_fn,
    .parser = function(items) length(items)
  )
  expect_equal(res, 5L)
  expect_equal(calls, 3L)
})

test_that("coinbase_paginate_cursor respects max_pages", {
  page <- list(accounts = list(list(uuid = "1")), has_next = TRUE, cursor = "c1")
  req_fn <- function(endpoint, query) return(page)
  res <- coinbase_paginate_cursor(
    endpoint = "/x",
    items_field = "accounts",
    max_pages = 2,
    .req_fn = req_fn,
    .parser = function(items) length(items)
  )
  # two pages of one item each, then capped
  expect_equal(res, 2L)
})
