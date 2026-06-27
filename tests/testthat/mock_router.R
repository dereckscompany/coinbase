# Shared mock HTTP router for the coinbase README, vignettes, and tests.
#
# This is the THIN coinbase-specific layer over connectcore's shared mock
# harness (connectcore::mock_router / with_mock_api / local_mock_api /
# load_fixtures / mock_response). connectcore owns the response builder, the
# dispatch loop, and the scoped-activation helpers; this file only declares the
# route table — URL pattern + HTTP method -> the captured fixture for that
# endpoint — and loads the fixtures from disk.
#
# Each route's fixture is the REAL captured Coinbase JSON for that endpoint,
# loaded verbatim from tests/testthat/fixtures/*.json by
# connectcore::load_fixtures() (a named list keyed by file basename; each value
# is the raw JSON string). connectcore::mock_response() serves a string body
# verbatim, so the parsers and column contracts are exercised against genuine
# exchange responses. The authenticated fixtures are scrubbed of the account's
# real UUIDs and balances (synthetic, deterministic) while preserving the exact
# JSON shape; the public market-data fixtures are verbatim.
#
# A handful of fixtures are deliberately hand-written rather than captured:
# the live test account holds no derivatives positions and a spot-only
# portfolio, so its real responses are empty/degenerate. For those routes
# (portfolio_breakdown, fills, futures_balance, futures_positions,
# futures_sweeps) the fixture file carries a representative populated body so
# the populated column contract stays exercised.
#
# httr2 exposes a native global mock hook: connectcore::with_mock_api(.mock_routes,
# { ... }) (or local_mock_api(.mock_routes)) installs the dispatcher as the
# httr2_mock option, intercepting every req_perform / req_perform_promise call,
# so docs render and tests run against canned, deterministic data with no
# network, no real credentials, and no funds. coinbase signs a JWT with the
# api_private_key BEFORE req_perform, so a (throwaway, ephemeral) key must still
# be loadable; the mock ignores the Authorization header entirely.
#
# Usage (in a hidden knitr setup chunk or a test):
#   box::use(./tests/testthat/mock_router[.mock_routes])
#   connectcore::with_mock_api(.mock_routes, { ...code... })  # scoped to a block
#   connectcore::local_mock_api(.mock_routes)                 # scoped to a frame

box::use(
  connectcore[load_fixtures]
)

# Load every captured fixture as its raw JSON string, keyed by file basename
# (accounts.json -> "accounts"). Resolved relative to THIS module file so it
# works from the package root (README), vignettes/, and tests/testthat alike.
.fixtures <- load_fixtures(box::file("fixtures"))

# POST setters that return 200 with an empty body (the intraday-margin setter):
# an empty string would fail JSON parsing, so serve a real empty-body response.
.empty_response <- function() {
  return(httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = raw(0)
  ))
}

#' Route table: URL pattern (+ optional method) -> captured-fixture JSON string.
#'
#' Order matters — more specific patterns first. Routes handle both Coinbase
#' hosts:
#'   Exchange (public):     https://api.exchange.coinbase.com
#'   Advanced Trade (auth): https://api.coinbase.com
#' Each `fixture` is the raw JSON string for that endpoint (served verbatim by
#' connectcore::mock_response); a few are a thunk returning a built response.
#' @export
.mock_routes <- list(
  # ---- Public Market Data (api.exchange.coinbase.com) ----

  # Product sub-resources (before single product, before product list)
  list(pattern = "/products/BTC-USD/candles", fixture = .fixtures$candles),
  list(pattern = "/products/BTC-USD/trades", fixture = .fixtures$trades),

  # Order book: the non-aggregated level-3 book (third element is an order_id
  # string) before the aggregated level-1/2 book (third element is a count).
  # The client sends the depth as a `?level=` query param, so match on that.
  list(pattern = "/products/BTC-USD/book?level=3", fixture = .fixtures$book_l3),
  list(pattern = "/products/BTC-USD/book", fixture = .fixtures$book_l2),
  list(pattern = "/products/BTC-USD/ticker", fixture = .fixtures$ticker),

  # Per-product stats (before single product, before the bulk stats + list)
  list(pattern = "/products/BTC-USD/stats", fixture = .fixtures$product_stats),

  # Single product (before the product list)
  list(pattern = "/products/BTC-USD", fixture = .fixtures$product),

  # Bulk all-product stats (before the product list)
  list(pattern = "/products/stats", fixture = .fixtures$stats),

  # Product list
  list(pattern = "/products", fixture = .fixtures$products),

  # Server time
  list(pattern = "/time", fixture = .fixtures$time),

  # ---- Account (api.coinbase.com Advanced Trade) ----

  # Single account by uuid (before the accounts list)
  list(pattern = "/api/v3/brokerage/accounts/", fixture = .fixtures$account),
  list(pattern = "/api/v3/brokerage/accounts", fixture = .fixtures$accounts),

  list(pattern = "/api/v3/brokerage/transaction_summary", fixture = .fixtures$transaction_summary),
  list(pattern = "/api/v3/brokerage/portfolios/", fixture = .fixtures$portfolio_breakdown),
  list(pattern = "/api/v3/brokerage/portfolios", fixture = .fixtures$portfolios),
  list(pattern = "/api/v3/brokerage/key_permissions", fixture = .fixtures$key_permissions),
  list(pattern = "/api/v3/brokerage/best_bid_ask", fixture = .fixtures$best_bid_ask, method = "GET"),

  # ---- Trading (api.coinbase.com Advanced Trade) ----

  # Historical sub-resources (before the single historical order)
  list(pattern = "/api/v3/brokerage/orders/historical/fills", fixture = .fixtures$fills),
  list(pattern = "/api/v3/brokerage/orders/historical/batch", fixture = .fixtures$orders),
  list(pattern = "/api/v3/brokerage/orders/historical/", fixture = .fixtures$order),

  # Order actions (before the generic /orders create)
  list(pattern = "/api/v3/brokerage/orders/preview", fixture = .fixtures$preview, method = "POST"),
  list(pattern = "/api/v3/brokerage/orders/edit_preview", fixture = .fixtures$edit_preview, method = "POST"),
  list(pattern = "/api/v3/brokerage/orders/edit", fixture = .fixtures$edit_order, method = "POST"),
  list(pattern = "/api/v3/brokerage/orders/batch_cancel", fixture = .fixtures$cancel_orders, method = "POST"),
  list(pattern = "/api/v3/brokerage/orders/close_position", fixture = .fixtures$close_position, method = "POST"),

  # Create order
  list(pattern = "/api/v3/brokerage/orders", fixture = .fixtures$create_order, method = "POST"),

  # ---- Futures (CFM) (api.coinbase.com Advanced Trade) ----

  list(pattern = "/api/v3/brokerage/cfm/balance_summary", fixture = .fixtures$futures_balance),

  # Single position by product (before the positions list)
  list(pattern = "/api/v3/brokerage/cfm/positions/", fixture = .fixtures$futures_position),
  list(pattern = "/api/v3/brokerage/cfm/positions", fixture = .fixtures$futures_positions),

  # Sweeps: schedule (before generic), list (GET), cancel (DELETE)
  list(pattern = "/api/v3/brokerage/cfm/sweeps/schedule", fixture = .fixtures$schedule_sweep, method = "POST"),
  list(pattern = "/api/v3/brokerage/cfm/sweeps", fixture = .fixtures$cancel_sweep, method = "DELETE"),
  list(pattern = "/api/v3/brokerage/cfm/sweeps", fixture = .fixtures$futures_sweeps, method = "GET"),

  # Intraday margin: current window, margin setting getter (GET) and setter (POST -> empty body)
  list(pattern = "/api/v3/brokerage/cfm/intraday/current_margin_window", fixture = .fixtures$current_margin_window),
  list(pattern = "/api/v3/brokerage/cfm/intraday/margin_setting", fixture = .empty_response, method = "POST"),
  list(
    pattern = "/api/v3/brokerage/cfm/intraday/margin_setting",
    fixture = .fixtures$intraday_margin_setting,
    method = "GET"
  )
)
