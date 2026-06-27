# File: R/CoinbaseAccount.R
# Authenticated account client for Coinbase Advanced Trade.

#' CoinbaseAccount: Account, Balance, and Fee Information
#'
#' Retrieves authenticated account data from the Coinbase Advanced Trade API:
#' trading accounts (balances), the transaction/fee summary, portfolios, and the
#' API key's permissions. All endpoints require credentials.
#'
#' Inherits from [CoinbaseBase]. All methods support both synchronous and
#' asynchronous execution depending on the `async` argument at construction.
#'
#' ### Pagination
#' `get_accounts()` walks Coinbase's body-cursor pagination (`cursor` /
#' `has_next`) to return all accounts across pages.
#'
#' ### Endpoints Covered
#' | Method | Endpoint | Auth |
#' |--------|----------|------|
#' | get_accounts | GET /api/v3/brokerage/accounts | Yes |
#' | get_account | GET /api/v3/brokerage/accounts/\{uuid\} | Yes |
#' | get_fees | GET /api/v3/brokerage/transaction_summary | Yes |
#' | get_portfolios | GET /api/v3/brokerage/portfolios | Yes |
#' | get_portfolio_breakdown | GET /api/v3/brokerage/portfolios/\{uuid\} | Yes |
#' | get_portfolio_summary | GET /api/v3/brokerage/portfolios/\{uuid\} | Yes |
#' | get_key_permissions | GET /api/v3/brokerage/key_permissions | Yes |
#'
#' @examples
#' \dontrun{
#' account <- CoinbaseAccount$new()
#' account$get_accounts()
#' account$get_fees()
#' }
#'
#' @import data.table
#' @export
CoinbaseAccount <- R6::R6Class(
  "CoinbaseAccount",
  inherit = CoinbaseBase,
  public = list(
    #' @description Retrieve all trading accounts (balances), paginating over the
    #'   cursor until exhausted.
    #' @param limit (scalar<count in [1, Inf[> | NULL) page size. Optional.
    #' @param max_pages (scalar<numeric in [1, Inf]>) cap on pages fetched.
    #'   Default `Inf`.
    #' @return (Accounts | promise<Accounts>) the accounts, or a promise thereof.
    get_accounts = function(limit = NULL, max_pages = Inf) {
      assert_args_CoinbaseAccount__get_accounts(limit, max_pages)
      res <- coinbase_paginate_cursor(
        endpoint = "/api/v3/brokerage/accounts",
        query = list(limit = limit),
        items_field = "accounts",
        .req_fn = private$.list_req_fn(),
        .parser = parse_accounts,
        max_pages = max_pages,
        is_async = private$.is_async
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseAccount__get_accounts,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve a single account by its UUID.
    #' @param account_uuid (scalar<character>) the account UUID.
    #' @return (Accounts | promise<Accounts>) a single-row table, or a promise
    #'   thereof.
    get_account = function(account_uuid) {
      assert_args_CoinbaseAccount__get_account(account_uuid)
      assert::assert_nonempty_strings(account_uuid)
      res <- private$.request(
        endpoint = paste0("/api/v3/brokerage/accounts/", account_uuid),
        auth = TRUE,
        .parser = function(body) parse_accounts(list(body$account))
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseAccount__get_account,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the transaction/fee summary, including the current
    #'   maker/taker fee tier.
    #' @param product_type (scalar<character> | NULL) `"SPOT"` or `"FUTURE"` to
    #'   scope the summary. Optional.
    #' @return (Fees | promise<Fees>) a single-row table, or a promise thereof.
    get_fees = function(product_type = NULL) {
      assert_args_CoinbaseAccount__get_fees(product_type)
      assert::assert_nonempty_strings(product_type, null_ok = TRUE)
      res <- private$.request(
        endpoint = "/api/v3/brokerage/transaction_summary",
        query = list(product_type = product_type),
        auth = TRUE,
        .parser = parse_fees
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseAccount__get_fees,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the user's portfolios.
    #' @return (data.table | promise<data.table>) the portfolios, or a promise
    #'   thereof.
    get_portfolios = function() {
      res <- private$.request(
        endpoint = "/api/v3/brokerage/portfolios",
        auth = TRUE,
        .parser = function(body) as_dt_list(body$portfolios)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseAccount__get_portfolios,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve a single portfolio's positions: its spot, futures,
    #'   and perpetual holdings stacked into one `data.table`, one row per
    #'   holding, tagged by a `position_type` column. The concepts shared across
    #'   types are normalised to common columns (`entry_price`, `mark_price`,
    #'   `side`, `unrealized_pnl`); the rest keep their API names. For the
    #'   portfolio's aggregate balance totals, use `get_portfolio_summary()` (it
    #'   reads the same endpoint).
    #' @param portfolio_uuid (scalar<character>) the portfolio UUID (from
    #'   `get_portfolios()`).
    #' @param currency (scalar<character> | NULL) quote currency for fiat values.
    #'   Optional.
    #' @return (data.table | promise<data.table>) the positions, or a promise
    #'   thereof.
    get_portfolio_breakdown = function(portfolio_uuid, currency = NULL) {
      assert_args_CoinbaseAccount__get_portfolio_breakdown(portfolio_uuid, currency)
      assert::assert_nonempty_strings(portfolio_uuid)
      assert::assert_nonempty_strings(currency, null_ok = TRUE)
      res <- private$.request(
        endpoint = paste0("/api/v3/brokerage/portfolios/", portfolio_uuid),
        query = list(currency = currency),
        auth = TRUE,
        .parser = parse_portfolio_breakdown
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseAccount__get_portfolio_breakdown,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve a single portfolio's aggregate balance totals (total
    #'   balance, futures/crypto/cash-equivalent balances, and futures/perp
    #'   unrealized PnL). The positions companion is `get_portfolio_breakdown()`;
    #'   both read the same endpoint.
    #' @param portfolio_uuid (scalar<character>) the portfolio UUID (from
    #'   `get_portfolios()`).
    #' @param currency (scalar<character> | NULL) quote currency for fiat values.
    #'   Optional.
    #' @return (PortfolioSummary | promise<PortfolioSummary>) a single-row table of
    #'   totals, or a promise thereof.
    get_portfolio_summary = function(portfolio_uuid, currency = NULL) {
      assert_args_CoinbaseAccount__get_portfolio_summary(portfolio_uuid, currency)
      assert::assert_nonempty_strings(portfolio_uuid)
      assert::assert_nonempty_strings(currency, null_ok = TRUE)
      res <- private$.request(
        endpoint = paste0("/api/v3/brokerage/portfolios/", portfolio_uuid),
        query = list(currency = currency),
        auth = TRUE,
        .parser = parse_portfolio_summary
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseAccount__get_portfolio_summary,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the calling API key's permissions.
    #' @return (data.table | promise<data.table>) a single-row table, or a promise
    #'   thereof.
    get_key_permissions = function() {
      res <- private$.request(
        endpoint = "/api/v3/brokerage/key_permissions",
        auth = TRUE,
        .parser = as_dt_row
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseAccount__get_key_permissions,
        is_async = private$.is_async
      ))
    }
  ),
  private = list(
    # Returns a request function for the cursor paginator: performs one
    # authenticated GET and returns the raw parsed body (cursor + items).
    .list_req_fn = function() {
      return(function(endpoint, query) {
        return(private$.request(
          endpoint = endpoint,
          query = query,
          auth = TRUE,
          .parser = identity
        ))
      })
    }
  )
)
