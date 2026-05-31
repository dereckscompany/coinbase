# File: R/CoinbaseTrading.R
# Authenticated trading client for Coinbase Advanced Trade.

#' CoinbaseTrading: Order Placement and Management
#'
#' Places, previews, edits, cancels, and queries orders and fills on the
#' Coinbase Advanced Trade API. All endpoints require credentials.
#'
#' Inherits from [CoinbaseBase]. All methods support both synchronous and
#' asynchronous execution depending on the `async` argument at construction.
#'
#' ### Order configuration
#' Orders carry an `order_configuration`: a one-key list naming the detailed
#' order type, e.g.
#' - `list(market_market_ioc = list(quote_size = "10"))` (market buy of $10)
#' - `list(limit_limit_gtc = list(base_size = "0.001", limit_price = "50000"))`
#' - `list(stop_limit_stop_limit_gtc = list(base_size = ..., limit_price = ...,`
#'   `stop_price = ..., stop_direction = "STOP_DIRECTION_STOP_DOWN"))`
#'
#' Use [preview_order()][CoinbaseTrading] (a dry run that places nothing) to
#' validate a configuration before submitting.
#'
#' ### Pagination
#' `get_orders()` and `get_fills()` walk the body-cursor pagination.
#'
#' ### Endpoints Covered
#' | Method | Endpoint | Auth |
#' |--------|----------|------|
#' | add_order | POST /api/v3/brokerage/orders | Yes |
#' | preview_order | POST /api/v3/brokerage/orders/preview | Yes |
#' | get_order | GET /api/v3/brokerage/orders/historical/\{id\} | Yes |
#' | get_orders | GET /api/v3/brokerage/orders/historical/batch | Yes |
#' | get_fills | GET /api/v3/brokerage/orders/historical/fills | Yes |
#' | edit_order | POST /api/v3/brokerage/orders/edit | Yes |
#' | preview_edit_order | POST /api/v3/brokerage/orders/edit_preview | Yes |
#' | cancel_orders | POST /api/v3/brokerage/orders/batch_cancel | Yes |
#'
#' @examples
#' \dontrun{
#' trading <- CoinbaseTrading$new()
#' # Validate without placing anything:
#' trading$preview_order("BTC-USD", "BUY", list(market_market_ioc = list(quote_size = "10")))
#' trading$get_orders(product_ids = "BTC-USD", limit = 10)
#' }
#'
#' @import data.table
#' @export
CoinbaseTrading <- R6::R6Class(
  "CoinbaseTrading",
  inherit = CoinbaseBase,
  public = list(
    #' @description Place a new order. The order is live and may execute; use
    #'   `preview_order()` first to validate.
    #' @param product_id Character; e.g. `"BTC-USD"`.
    #' @param side Character; `"BUY"` or `"SELL"`.
    #' @param order_configuration Named list; the one-key order configuration.
    #' @param client_order_id Character; idempotency key. Defaults to a fresh
    #'   UUID via [generate_client_order_id()].
    #' @return A single-row [data.table::data.table] with `success`, the scalar
    #'   `order_id`, `product_id`, `side`, `client_order_id`, `failure_reason`,
    #'   and flattened order-configuration columns, or a promise thereof.
    add_order = function(product_id, side, order_configuration, client_order_id = generate_client_order_id()) {
      validate_symbol(product_id)
      side <- validate_side(side)
      validate_order_config(order_configuration)
      assert::assert_scalar_character(client_order_id)
      body <- list(
        client_order_id = client_order_id,
        product_id = product_id,
        side = side,
        order_configuration = order_configuration
      )
      return(private$.request(
        endpoint = "/api/v3/brokerage/orders",
        method = "POST",
        body = body,
        auth = TRUE,
        .parser = parse_create_order
      ))
    },

    #' @description Preview an order without placing it (dry run; executes
    #'   nothing). Returns the estimated total, commission, sizes, and any
    #'   validation errors.
    #' @param product_id Character; e.g. `"BTC-USD"`.
    #' @param side Character; `"BUY"` or `"SELL"`.
    #' @param order_configuration Named list; the one-key order configuration.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    preview_order = function(product_id, side, order_configuration) {
      validate_symbol(product_id)
      side <- validate_side(side)
      validate_order_config(order_configuration)
      body <- list(
        product_id = product_id,
        side = side,
        order_configuration = order_configuration
      )
      return(private$.request(
        endpoint = "/api/v3/brokerage/orders/preview",
        method = "POST",
        body = body,
        auth = TRUE,
        .parser = parse_preview
      ))
    },

    #' @description Retrieve a single order by its ID.
    #' @param order_id Character; the order ID.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    get_order = function(order_id) {
      assert::assert_scalar_character(order_id)
      return(private$.request(
        endpoint = paste0("/api/v3/brokerage/orders/historical/", order_id),
        auth = TRUE,
        .parser = function(b) parse_orders(list(b$order))
      ))
    },

    #' @description Retrieve historical orders, paginating over the cursor.
    #' @param product_ids Character vector or NULL; filter by product(s).
    #' @param order_status Character vector or NULL; e.g. `"OPEN"`, `"FILLED"`,
    #'   `"CANCELLED"`.
    #' @param order_side Character or NULL; `"BUY"` or `"SELL"`.
    #' @param limit Integer or NULL; page size.
    #' @param max_pages Numeric; cap on pages fetched. Default `Inf`.
    #' @return A [data.table::data.table] of orders, or a promise thereof.
    get_orders = function(product_ids = NULL, order_status = NULL, order_side = NULL, limit = NULL, max_pages = Inf) {
      return(coinbase_paginate_cursor(
        endpoint = "/api/v3/brokerage/orders/historical/batch",
        query = list(
          product_ids = product_ids,
          order_status = order_status,
          order_side = order_side,
          limit = limit
        ),
        items_field = "orders",
        .req_fn = private$.list_req_fn(),
        .parser = parse_orders,
        max_pages = max_pages,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve historical fills, paginating over the cursor.
    #' @param order_id Character or NULL; filter by order.
    #' @param product_ids Character vector or NULL; filter by product(s).
    #' @param limit Integer or NULL; page size.
    #' @param max_pages Numeric; cap on pages fetched. Default `Inf`.
    #' @return A [data.table::data.table] of fills, or a promise thereof.
    get_fills = function(order_id = NULL, product_ids = NULL, limit = NULL, max_pages = Inf) {
      return(coinbase_paginate_cursor(
        endpoint = "/api/v3/brokerage/orders/historical/fills",
        query = list(
          order_ids = order_id,
          product_ids = product_ids,
          limit = limit
        ),
        items_field = "fills",
        .req_fn = private$.list_req_fn(),
        .parser = parse_fills,
        max_pages = max_pages,
        is_async = private$.is_async
      ))
    },

    #' @description Edit an open order's price and/or size.
    #' @param order_id Character; the order ID.
    #' @param price Character/numeric or NULL; new limit price.
    #' @param size Character/numeric or NULL; new size.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    edit_order = function(order_id, price = NULL, size = NULL) {
      assert::assert_scalar_character(order_id)
      if (is.null(price) && is.null(size)) {
        rlang::abort("edit_order requires at least one of `price` or `size`.")
      }
      price <- if (!is.null(price)) coerce_positive_string(price, "price") else NULL
      size <- if (!is.null(size)) coerce_positive_string(size, "size") else NULL
      return(private$.request(
        endpoint = "/api/v3/brokerage/orders/edit",
        method = "POST",
        body = list(order_id = order_id, price = price, size = size),
        auth = TRUE,
        .parser = parse_edit_order
      ))
    },

    #' @description Preview an order edit without applying it (dry run).
    #' @param order_id Character; the order ID.
    #' @param price Character/numeric or NULL; proposed limit price.
    #' @param size Character/numeric or NULL; proposed size.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    preview_edit_order = function(order_id, price = NULL, size = NULL) {
      assert::assert_scalar_character(order_id)
      if (is.null(price) && is.null(size)) {
        rlang::abort("preview_edit_order requires at least one of `price` or `size`.")
      }
      price <- if (!is.null(price)) coerce_positive_string(price, "price") else NULL
      size <- if (!is.null(size)) coerce_positive_string(size, "size") else NULL
      return(private$.request(
        endpoint = "/api/v3/brokerage/orders/edit_preview",
        method = "POST",
        body = list(order_id = order_id, price = price, size = size),
        auth = TRUE,
        .parser = parse_edit_preview
      ))
    },

    #' @description Cancel one or more open orders.
    #' @param order_ids Character vector; the order IDs to cancel.
    #' @return A [data.table::data.table] of per-order cancel results, or a
    #'   promise thereof.
    cancel_orders = function(order_ids) {
      assert::assert_character(order_ids)
      if (length(order_ids) == 0L) {
        rlang::abort("`order_ids` must contain at least one order id.")
      }
      return(private$.request(
        endpoint = "/api/v3/brokerage/orders/batch_cancel",
        method = "POST",
        body = list(order_ids = as.list(order_ids)),
        auth = TRUE,
        .parser = function(b) parse_cancel_results(b$results)
      ))
    }
  ),
  private = list(
    # Request function for the cursor paginator: one authenticated GET returning
    # the raw parsed body (cursor + items).
    .list_req_fn = function() {
      return(function(endpoint, query) {
        return(private$.request(endpoint = endpoint, query = query, auth = TRUE, .parser = identity))
      })
    }
  )
)
