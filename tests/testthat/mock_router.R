# Shared mock HTTP router for the coinbase README and vignettes.
#
# Dispatches httr2 requests to fixture data based on URL pattern matching.
# Fixtures come from helper-mockery.R; this file only handles routing logic.
#
# httr2 exposes a native global mock hook: `options(httr2_mock = mock_router)`
# intercepts every req_perform / req_perform_promise call. coinbase uses httr2,
# so docs render against canned, deterministic data with no network, no real
# credentials, and no funds. coinbase signs a JWT with the api_private_key
# BEFORE req_perform, so a (throwaway, ephemeral) key must still be loadable;
# the mock ignores the Authorization header entirely.
#
# Usage (in a hidden knitr setup chunk):
#   box::use(./tests/testthat/mock_router[mock_router])
#   options(httr2_mock = mock_router)

# Load all fixtures from helper-mockery.R (sibling file)
box::use(./`helper-mockery`[
  mock_cb_response, mock_cb_empty_response,
  # Public Market Data (Exchange host)
  mock_cb_products_response, mock_cb_product_response,
  mock_cb_candles_response, mock_cb_trades_response,
  mock_cb_book_response, mock_cb_book_l3_response,
  mock_cb_ticker_response, mock_cb_time_response,
  # Account (Advanced Trade host)
  mock_cb_accounts_response, mock_cb_account_response,
  mock_cb_fees_response, mock_cb_portfolios_response,
  mock_cb_key_permissions_response,
  # Trading (Advanced Trade host)
  mock_cb_orders_response, mock_cb_order_response,
  mock_cb_fills_response, mock_cb_preview_response,
  mock_cb_create_order_response, mock_cb_edit_order_response,
  mock_cb_edit_preview_response, mock_cb_cancel_orders_response,
  # Futures (CFM) (Advanced Trade host)
  mock_cb_futures_balance_response, mock_cb_futures_positions_response,
  mock_cb_futures_position_response, mock_cb_futures_sweeps_response,
  mock_cb_schedule_sweep_response, mock_cb_cancel_sweep_response,
  mock_cb_intraday_margin_setting_response,
  mock_cb_current_margin_window_response
])

#' Route table: URL pattern -> fixture thunk
#' Order matters — more specific patterns first.
#' Routes handle both Coinbase hosts:
#'   Exchange (public):     https://api.exchange.coinbase.com
#'   Advanced Trade (auth): https://api.coinbase.com
#' @keywords internal
.mock_routes <- list(
  # ---- Public Market Data (api.exchange.coinbase.com) ----

  # Product sub-resources (before single product, before product list)
  list(pattern = "/products/BTC-USD/candles", fixture = function() return(mock_cb_candles_response())),
  list(pattern = "/products/BTC-USD/trades", fixture = function() return(mock_cb_trades_response())),

  # Order book: the non-aggregated level-3 book (third element is an order_id
  # string) before the aggregated level-1/2 book (third element is a count).
  # The client sends the depth as a `?level=` query param, so match on that.
  list(pattern = "/products/BTC-USD/book?level=3", fixture = function() return(mock_cb_book_l3_response())),
  list(pattern = "/products/BTC-USD/book", fixture = function() return(mock_cb_book_response())),
  list(pattern = "/products/BTC-USD/ticker", fixture = function() return(mock_cb_ticker_response())),

  # Single product (before the product list)
  list(pattern = "/products/BTC-USD", fixture = function() return(mock_cb_product_response())),

  # Product list
  list(pattern = "/products", fixture = function() return(mock_cb_products_response())),

  # Server time
  list(pattern = "/time", fixture = function() return(mock_cb_time_response())),

  # ---- Account (api.coinbase.com Advanced Trade) ----

  # Single account by uuid (before the accounts list)
  list(pattern = "/api/v3/brokerage/accounts/", fixture = function() return(mock_cb_account_response())),
  list(pattern = "/api/v3/brokerage/accounts", fixture = function() return(mock_cb_accounts_response())),

  list(pattern = "/api/v3/brokerage/transaction_summary", fixture = function() return(mock_cb_fees_response())),
  list(pattern = "/api/v3/brokerage/portfolios", fixture = function() return(mock_cb_portfolios_response())),
  list(pattern = "/api/v3/brokerage/key_permissions", fixture = function() return(mock_cb_key_permissions_response())),

  # ---- Trading (api.coinbase.com Advanced Trade) ----

  # Historical sub-resources (before the single historical order)
  list(pattern = "/api/v3/brokerage/orders/historical/fills", fixture = function() return(mock_cb_fills_response())),
  list(pattern = "/api/v3/brokerage/orders/historical/batch", fixture = function() return(mock_cb_orders_response())),
  list(pattern = "/api/v3/brokerage/orders/historical/", fixture = function() return(mock_cb_order_response())),

  # Order actions (before the generic /orders create)
  list(pattern = "/api/v3/brokerage/orders/preview", fixture = function() return(mock_cb_preview_response()), method = "POST"),
  list(pattern = "/api/v3/brokerage/orders/edit_preview", fixture = function() return(mock_cb_edit_preview_response()), method = "POST"),
  list(pattern = "/api/v3/brokerage/orders/edit", fixture = function() return(mock_cb_edit_order_response()), method = "POST"),
  list(pattern = "/api/v3/brokerage/orders/batch_cancel", fixture = function() return(mock_cb_cancel_orders_response()), method = "POST"),

  # Create order
  list(pattern = "/api/v3/brokerage/orders", fixture = function() return(mock_cb_create_order_response()), method = "POST"),

  # ---- Futures (CFM) (api.coinbase.com Advanced Trade) ----

  list(pattern = "/api/v3/brokerage/cfm/balance_summary", fixture = function() return(mock_cb_futures_balance_response())),

  # Single position by product (before the positions list)
  list(pattern = "/api/v3/brokerage/cfm/positions/", fixture = function() return(mock_cb_futures_position_response())),
  list(pattern = "/api/v3/brokerage/cfm/positions", fixture = function() return(mock_cb_futures_positions_response())),

  # Sweeps: schedule (before generic), list (GET), cancel (DELETE)
  list(pattern = "/api/v3/brokerage/cfm/sweeps/schedule", fixture = function() return(mock_cb_schedule_sweep_response()), method = "POST"),
  list(pattern = "/api/v3/brokerage/cfm/sweeps", fixture = function() return(mock_cb_cancel_sweep_response()), method = "DELETE"),
  list(pattern = "/api/v3/brokerage/cfm/sweeps", fixture = function() return(mock_cb_futures_sweeps_response()), method = "GET"),

  # Intraday margin: current window, margin setting getter (GET) and setter (POST -> empty body)
  list(pattern = "/api/v3/brokerage/cfm/intraday/current_margin_window", fixture = function() return(mock_cb_current_margin_window_response())),
  list(pattern = "/api/v3/brokerage/cfm/intraday/margin_setting", fixture = function() return(mock_cb_empty_response()), method = "POST"),
  list(pattern = "/api/v3/brokerage/cfm/intraday/margin_setting", fixture = function() return(mock_cb_intraday_margin_setting_response()), method = "GET")
)

#' Mock HTTP router for README and vignettes
#'
#' Dispatches `httr2` requests to fixture data based on URL pattern matching.
#' Set via `options(httr2_mock = mock_router)` in a hidden knitr setup chunk.
#'
#' Handles both Coinbase hosts:
#' - Exchange (public):     `https://api.exchange.coinbase.com`
#' - Advanced Trade (auth): `https://api.coinbase.com`
#'
#' @param req An `httr2_request` object.
#' @return An `httr2_response` object.
#' @export
mock_router <- function(req) {
  url <- req$url
  method <- req$method

  # Route table lookup
  for (route in .mock_routes) {
    if (grepl(route$pattern, url, fixed = TRUE)) {
      if (!is.null(route$method) && method != route$method) {
        next
      }
      fixture_data <- route$fixture()
      # mock_cb_empty_response returns an httr2_response directly
      if (inherits(fixture_data, "httr2_response")) {
        return(fixture_data)
      }
      return(mock_cb_response(fixture_data))
    }
  }

  stop("Unmocked request: ", method, " ", url)
}
