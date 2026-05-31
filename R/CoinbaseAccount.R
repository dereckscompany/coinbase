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
    #' @param limit Integer or NULL; page size. Optional.
    #' @param max_pages Numeric; cap on pages fetched. Default `Inf`.
    #' @return A [data.table::data.table] of accounts, or a promise thereof.
    get_accounts = function(limit = NULL, max_pages = Inf) {
      return(coinbase_paginate_cursor(
        endpoint = "/api/v3/brokerage/accounts",
        query = list(limit = limit),
        items_field = "accounts",
        .req_fn = private$.list_req_fn(),
        .parser = parse_accounts,
        max_pages = max_pages,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve a single account by its UUID.
    #' @param account_uuid Character; the account UUID.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    get_account = function(account_uuid) {
      assert::assert_scalar_character(account_uuid)
      return(private$.request(
        endpoint = paste0("/api/v3/brokerage/accounts/", account_uuid),
        auth = TRUE,
        .parser = function(body) parse_accounts(list(body$account))
      ))
    },

    #' @description Retrieve the transaction/fee summary, including the current
    #'   maker/taker fee tier.
    #' @param product_type Character or NULL; `"SPOT"` or `"FUTURE"` to scope the
    #'   summary. Optional.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    get_fees = function(product_type = NULL) {
      return(private$.request(
        endpoint = "/api/v3/brokerage/transaction_summary",
        query = list(product_type = product_type),
        auth = TRUE,
        .parser = parse_fees
      ))
    },

    #' @description Retrieve the user's portfolios.
    #' @return A [data.table::data.table] of portfolios, or a promise thereof.
    get_portfolios = function() {
      return(private$.request(
        endpoint = "/api/v3/brokerage/portfolios",
        auth = TRUE,
        .parser = function(body) as_dt_list(body$portfolios)
      ))
    },

    #' @description Retrieve the calling API key's permissions.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    get_key_permissions = function() {
      return(private$.request(
        endpoint = "/api/v3/brokerage/key_permissions",
        auth = TRUE,
        .parser = as_dt_row
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
