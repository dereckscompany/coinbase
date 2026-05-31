# File: R/CoinbaseFutures.R
# Authenticated US futures (Coinbase Financial Markets / CFM) client.

#' CoinbaseFutures: US Futures (CFM) Account, Positions, and Margin
#'
#' Manages the Coinbase Financial Markets (CFM) US futures account: balance
#' summary, open positions, cash sweeps between the spot (CBI) and futures (CFM)
#' accounts, and intraday margin settings. All endpoints require credentials and
#' a funded, approved CFM futures account.
#'
#' Inherits from [CoinbaseBase]. All methods support both synchronous and
#' asynchronous execution depending on the `async` argument at construction.
#'
#' ### Placing futures orders (the short leg)
#' Futures **orders are placed through the same order endpoint as spot** — use
#' [CoinbaseTrading] with a futures `product_id` and a futures order
#' configuration. To open a short, submit a `SELL` order on the futures product
#' (e.g. a nano-BTC contract). This class manages the surrounding account state
#' (margin, positions, balances, sweeps); it does not place orders itself.
#'
#' @section Note on perpetuals:
#' Coinbase's INTX perpetual-futures endpoints (`/intx/*`) are for eligible
#' **non-US** jurisdictions and are intentionally not wrapped here; US customers
#' trade the CFM futures covered by this class.
#'
#' ### Endpoints Covered
#' | Method | Endpoint | Auth |
#' |--------|----------|------|
#' | get_balance_summary | GET /api/v3/brokerage/cfm/balance_summary | Yes |
#' | get_positions | GET /api/v3/brokerage/cfm/positions | Yes |
#' | get_position | GET /api/v3/brokerage/cfm/positions/\{id\} | Yes |
#' | schedule_sweep | POST /api/v3/brokerage/cfm/sweeps/schedule | Yes |
#' | get_sweeps | GET /api/v3/brokerage/cfm/sweeps | Yes |
#' | cancel_sweep | DELETE /api/v3/brokerage/cfm/sweeps | Yes |
#' | get_intraday_margin_setting | GET /api/v3/brokerage/cfm/intraday/margin_setting | Yes |
#' | set_intraday_margin_setting | POST /api/v3/brokerage/cfm/intraday/margin_setting | Yes |
#' | get_current_margin_window | GET /api/v3/brokerage/cfm/intraday/current_margin_window | Yes |
#'
#' @examples
#' \dontrun{
#' futures <- CoinbaseFutures$new()
#' futures$get_balance_summary()
#' futures$get_positions()
#' # Open a short via the shared order endpoint:
#' # CoinbaseTrading$new()$add_order("BIT-28FEB25-CDE", "SELL",
#' #   list(market_market_ioc = list(base_size = "1")))
#' }
#'
#' @import data.table
#' @export
CoinbaseFutures <- R6::R6Class(
  "CoinbaseFutures",
  inherit = CoinbaseBase,
  public = list(
    #' @description Retrieve the CFM futures balance summary (buying power,
    #'   margin, unrealised PnL, liquidation thresholds).
    #' @return A single-row [data.table::data.table], or a promise thereof.
    get_balance_summary = function() {
      return(private$.request(
        endpoint = "/api/v3/brokerage/cfm/balance_summary",
        auth = TRUE,
        .parser = function(b) parse_futures_balance(b$balance_summary)
      ))
    },

    #' @description Retrieve all open CFM futures positions.
    #' @return A [data.table::data.table] of positions, or a promise thereof.
    get_positions = function() {
      return(private$.request(
        endpoint = "/api/v3/brokerage/cfm/positions",
        auth = TRUE,
        .parser = function(b) parse_futures_positions(b$positions)
      ))
    },

    #' @description Retrieve a single CFM futures position by product.
    #' @param product_id Character; the futures product ID.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    get_position = function(product_id) {
      validate_symbol(product_id)
      return(private$.request(
        endpoint = paste0("/api/v3/brokerage/cfm/positions/", product_id),
        auth = TRUE,
        .parser = function(b) parse_futures_positions(list(b$position))
      ))
    },

    #' @description Schedule a cash sweep from the CFM futures account to the
    #'   spot (CBI) USD wallet.
    #' @param usd_amount Character/numeric; positive amount in USD to sweep.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    schedule_sweep = function(usd_amount) {
      amount <- coerce_positive_string(usd_amount, "usd_amount")
      return(private$.request(
        endpoint = "/api/v3/brokerage/cfm/sweeps/schedule",
        method = "POST",
        body = list(usd_amount = amount),
        auth = TRUE,
        .parser = as_dt_row
      ))
    },

    #' @description Retrieve scheduled and pending futures sweeps.
    #' @return A [data.table::data.table] of sweeps, or a promise thereof.
    get_sweeps = function() {
      return(private$.request(
        endpoint = "/api/v3/brokerage/cfm/sweeps",
        auth = TRUE,
        .parser = function(b) parse_futures_sweeps(b$sweeps)
      ))
    },

    #' @description Cancel the pending futures sweep.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    cancel_sweep = function() {
      return(private$.request(
        endpoint = "/api/v3/brokerage/cfm/sweeps",
        method = "DELETE",
        auth = TRUE,
        .parser = as_dt_row
      ))
    },

    #' @description Retrieve the current intraday margin setting.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    get_intraday_margin_setting = function() {
      return(private$.request(
        endpoint = "/api/v3/brokerage/cfm/intraday/margin_setting",
        auth = TRUE,
        .parser = as_dt_row
      ))
    },

    #' @description Set the intraday margin setting.
    #' @param setting Character; e.g. `"INTRADAY_MARGIN_SETTING_STANDARD"` or
    #'   `"INTRADAY_MARGIN_SETTING_INTRADAY"`.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    set_intraday_margin_setting = function(setting) {
      assert::assert_scalar_character(setting)
      return(private$.request(
        endpoint = "/api/v3/brokerage/cfm/intraday/margin_setting",
        method = "POST",
        body = list(setting = setting),
        auth = TRUE,
        .parser = as_dt_row
      ))
    },

    #' @description Retrieve the current margin window.
    #' @param margin_profile_type Character; the margin profile type (required by
    #'   the API), e.g. `"MARGIN_PROFILE_TYPE_RETAIL_INTRADAY_MARGIN_1"`.
    #' @return A single-row [data.table::data.table] with `margin_window_type`,
    #'   `end_time`, and the killswitch flags, or a promise thereof.
    get_current_margin_window = function(margin_profile_type) {
      assert::assert_scalar_character(margin_profile_type)
      return(private$.request(
        endpoint = "/api/v3/brokerage/cfm/intraday/current_margin_window",
        query = list(margin_profile_type = margin_profile_type),
        auth = TRUE,
        .parser = parse_margin_window
      ))
    }
  )
)
