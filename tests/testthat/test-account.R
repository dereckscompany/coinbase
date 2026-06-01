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
    idx <- 1L
    if (!is.null(query$cursor)) {
      idx <- as.integer(sub("c", "", query$cursor)) + 1L
    }
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

test_that("coinbase_paginate_cursor keeps paging when has_next is ABSENT (fills shape)", {
  # The fills endpoint returns only {fills, cursor} -- no has_next. The walk must
  # continue while the cursor is non-empty, not stop after page 1.
  pages <- list(
    list(fills = list(list(id = "1"), list(id = "2")), cursor = "P2"),
    list(fills = list(list(id = "3")), cursor = "")
  )
  req_fn <- function(endpoint, query) {
    idx <- 1L
    if (!is.null(query$cursor)) {
      idx <- as.integer(sub("P", "", query$cursor))
    }
    return(pages[[idx]])
  }
  res <- coinbase_paginate_cursor(
    endpoint = "/x",
    items_field = "fills",
    .req_fn = req_fn,
    .parser = function(items) length(items)
  )
  expect_equal(res, 3L) # all pages, not just the first 2 items
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

test_that("parse_portfolio_breakdown stacks spot/futures/perp into one positions table", {
  resp <- list(
    breakdown = list(
      portfolio = list(name = "Algo", uuid = "p-1", type = "CONSUMER"),
      portfolio_balances = list(
        total_balance = list(value = "125000", currency = "USD"),
        total_futures_balance = list(value = "25000", currency = "USD"),
        total_crypto_balance = list(value = "85000", currency = "USD"),
        futures_unrealized_pnl = list(value = "120", currency = "USD"),
        perp_unrealized_pnl = list(value = "45", currency = "USD")
      ),
      spot_positions = list(
        list(
          asset = "BTC",
          account_uuid = "a1",
          total_balance_crypto = 0.81,
          total_balance_fiat = 60000,
          allocation = 0.48,
          unrealized_pnl = 5000,
          average_entry_price = list(value = "67900", currency = "USD"),
          cost_basis = list(value = "55000", currency = "USD"),
          is_cash = FALSE
        ),
        list(
          asset = "USD",
          account_uuid = "a2",
          total_balance_fiat = 40000,
          allocation = 0.32,
          is_cash = TRUE
        )
      ),
      futures_positions = list(
        list(
          product_id = "BIT-28FEB26-CDE",
          side = "LONG",
          amount = 2,
          contract_size = 0.01,
          avg_entry_price = "95000",
          current_price = "96000",
          unrealized_pnl = "120",
          notional_value = "1920",
          expiry = "2026-02-28T00:00:00Z",
          underlying_asset = "BTC",
          venue = "FCM"
        )
      ),
      perp_positions = list(
        list(
          product_id = "BTC-PERP-INTX",
          symbol = "BTC-PERP",
          position_side = "LONG",
          net_size = "1.5",
          vwap = list(
            userNativeCurrency = list(value = "94000", currency = "USD"),
            rawCurrency = list(value = "94000", currency = "USDC")
          ),
          mark_price = list(
            userNativeCurrency = list(value = "95500", currency = "USD"),
            rawCurrency = list(value = "95500", currency = "USDC")
          ),
          unrealized_pnl = list(
            userNativeCurrency = list(value = "45", currency = "USD"),
            rawCurrency = list(value = "45", currency = "USDC")
          ),
          liquidation_price = list(
            userNativeCurrency = list(value = "80000", currency = "USD"),
            rawCurrency = list(value = "80000", currency = "USDC")
          ),
          leverage = "5",
          margin_type = "CROSS"
        )
      )
    )
  )
  dt <- parse_portfolio_breakdown(resp)
  expect_equal(nrow(dt), 4L) # 2 spot + 1 futures + 1 perp
  expect_true("position_type" %in% names(dt))
  expect_equal(sort(unique(dt$position_type)), c("futures", "perp", "spot"))
  # normalised shared columns, flattened across Amount and BalancePair shapes
  expect_equal(dt[asset == "BTC"]$entry_price, 67900)
  expect_equal(dt[position_type == "futures"]$entry_price, 95000)
  expect_equal(dt[position_type == "futures"]$mark_price, 96000)
  expect_equal(dt[position_type == "perp"]$entry_price, 94000) # BalancePair userNativeCurrency
  expect_equal(dt[position_type == "perp"]$mark_price, 95500)
  expect_equal(dt[position_type == "perp"]$unrealized_pnl, 45)
  expect_equal(dt[position_type == "perp"]$liquidation_price, 80000)
  # futures expiry parses to POSIXct
  expect_true(inherits(dt[position_type == "futures"]$expiry, "POSIXct"))
  # no list columns, and no summary attribute (totals live in a separate method)
  expect_false(any(vapply(dt, is.list, logical(1))))
  expect_null(attr(dt, "summary"))
})

test_that("parse_portfolio_summary returns a one-row totals table", {
  resp <- list(
    breakdown = list(
      portfolio = list(name = "Algo", uuid = "p-1", type = "CONSUMER"),
      portfolio_balances = list(
        total_balance = list(value = "125000", currency = "USD"),
        total_futures_balance = list(value = "25000", currency = "USD"),
        total_crypto_balance = list(value = "85000", currency = "USD"),
        futures_unrealized_pnl = list(value = "120", currency = "USD"),
        perp_unrealized_pnl = list(value = "45", currency = "USD")
      )
    )
  )
  s <- parse_portfolio_summary(resp)
  expect_true(data.table::is.data.table(s))
  expect_equal(nrow(s), 1L)
  expect_equal(s$uuid, "p-1")
  expect_equal(s$total_balance, 125000)
  expect_equal(s$futures_unrealized_pnl, 120)
  expect_equal(s$perp_unrealized_pnl, 45)
  expect_false(any(vapply(s, is.list, logical(1))))
})

test_that("parse_portfolio_breakdown handles no positions (empty table, no attribute)", {
  dt <- parse_portfolio_breakdown(list(
    breakdown = list(
      portfolio = list(uuid = "p-2"),
      portfolio_balances = list(total_balance = list(value = "0", currency = "USD"))
    )
  ))
  expect_equal(nrow(dt), 0L)
  expect_null(attr(dt, "summary"))
})
