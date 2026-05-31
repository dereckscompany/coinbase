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
    #' @param self_trade_prevention_id Character or NULL; self-trade-prevention
    #'   group id. Optional.
    #' @param leverage Character or NULL; leverage for the order (e.g. `"2"`).
    #'   Optional.
    #' @param margin_type Character or NULL; `"CROSS"` or `"ISOLATED"`. Optional.
    #' @param retail_portfolio_id Character or NULL; portfolio to route the order
    #'   to. Optional.
    #' @return A single-row [data.table::data.table] with `success`, the scalar
    #'   `order_id`, `product_id`, `side`, `client_order_id`, `failure_reason`,
    #'   and flattened order-configuration columns, or a promise thereof.
    add_order = function(
      product_id,
      side,
      order_configuration,
      client_order_id = generate_client_order_id(),
      self_trade_prevention_id = NULL,
      leverage = NULL,
      margin_type = NULL,
      retail_portfolio_id = NULL
    ) {
      validate_symbol(product_id)
      side <- validate_side(side)
      validate_order_config(order_configuration)
      order_configuration <- stringify_order_config(order_configuration)
      assert::assert_scalar_character(client_order_id)
      body <- list(
        client_order_id = client_order_id,
        product_id = product_id,
        side = side,
        order_configuration = order_configuration,
        self_trade_prevention_id = self_trade_prevention_id,
        leverage = leverage,
        margin_type = margin_type,
        retail_portfolio_id = retail_portfolio_id
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
    #' @param leverage Character or NULL; leverage for the order. Optional.
    #' @param margin_type Character or NULL; `"CROSS"` or `"ISOLATED"`. Optional.
    #' @param retail_portfolio_id Character or NULL; portfolio to scope the
    #'   preview to. Optional.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    preview_order = function(
      product_id,
      side,
      order_configuration,
      leverage = NULL,
      margin_type = NULL,
      retail_portfolio_id = NULL
    ) {
      validate_symbol(product_id)
      side <- validate_side(side)
      validate_order_config(order_configuration)
      order_configuration <- stringify_order_config(order_configuration)
      body <- list(
        product_id = product_id,
        side = side,
        order_configuration = order_configuration,
        leverage = leverage,
        margin_type = margin_type,
        retail_portfolio_id = retail_portfolio_id
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
    #' @param order_ids Character vector or NULL; filter by specific order id(s).
    #' @param start_date,end_date Character or NULL; RFC 3339 bounds on order
    #'   creation time.
    #' @param order_types Character vector or NULL; e.g. `"LIMIT"`, `"MARKET"`.
    #' @param product_type Character or NULL; `"SPOT"` or `"FUTURE"`.
    #' @param order_placement_source Character or NULL; e.g. `"RETAIL_ADVANCED"`.
    #' @param contract_expiry_type Character or NULL; e.g. `"EXPIRING"`.
    #' @param asset_filters Character vector or NULL; filter by asset.
    #' @param retail_portfolio_id Character or NULL; scope to a portfolio.
    #' @param time_in_forces Character vector or NULL; e.g. `"GOOD_UNTIL_CANCELLED"`.
    #' @param sort_by Character or NULL; sort field, e.g. `"LAST_FILL_TIME"`.
    #' @param max_pages Numeric; cap on pages fetched. Default `Inf`.
    #' @return A [data.table::data.table] of orders, or a promise thereof.
    get_orders = function(
      product_ids = NULL,
      order_status = NULL,
      order_side = NULL,
      limit = NULL,
      order_ids = NULL,
      start_date = NULL,
      end_date = NULL,
      order_types = NULL,
      product_type = NULL,
      order_placement_source = NULL,
      contract_expiry_type = NULL,
      asset_filters = NULL,
      retail_portfolio_id = NULL,
      time_in_forces = NULL,
      sort_by = NULL,
      max_pages = Inf
    ) {
      return(coinbase_paginate_cursor(
        endpoint = "/api/v3/brokerage/orders/historical/batch",
        query = list(
          product_ids = product_ids,
          order_status = order_status,
          order_side = order_side,
          limit = limit,
          order_ids = order_ids,
          start_date = start_date,
          end_date = end_date,
          order_types = order_types,
          product_type = product_type,
          order_placement_source = order_placement_source,
          contract_expiry_type = contract_expiry_type,
          asset_filters = asset_filters,
          retail_portfolio_id = retail_portfolio_id,
          time_in_forces = time_in_forces,
          sort_by = sort_by
        ),
        items_field = "orders",
        .req_fn = private$.list_req_fn(),
        .parser = parse_orders,
        max_pages = max_pages,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve historical fills, paginating over the cursor.
    #' @param order_ids Character vector or NULL; filter by order id(s).
    #' @param trade_ids Character vector or NULL; filter by trade id(s).
    #' @param product_ids Character vector or NULL; filter by product(s).
    #' @param start_sequence_timestamp,end_sequence_timestamp Character or NULL;
    #'   RFC 3339 bounds on fill sequence time.
    #' @param retail_portfolio_id Character or NULL; scope to a portfolio.
    #' @param limit Integer or NULL; page size.
    #' @param sort_by Character or NULL; sort field, e.g. `"TRADE_TIME"`.
    #' @param max_pages Numeric; cap on pages fetched. Default `Inf`.
    #' @return A [data.table::data.table] of fills, or a promise thereof.
    get_fills = function(
      order_ids = NULL,
      trade_ids = NULL,
      product_ids = NULL,
      start_sequence_timestamp = NULL,
      end_sequence_timestamp = NULL,
      retail_portfolio_id = NULL,
      limit = NULL,
      sort_by = NULL,
      max_pages = Inf
    ) {
      return(coinbase_paginate_cursor(
        endpoint = "/api/v3/brokerage/orders/historical/fills",
        query = list(
          order_ids = order_ids,
          trade_ids = trade_ids,
          product_ids = product_ids,
          start_sequence_timestamp = start_sequence_timestamp,
          end_sequence_timestamp = end_sequence_timestamp,
          retail_portfolio_id = retail_portfolio_id,
          limit = limit,
          sort_by = sort_by
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
    },

    #' @description Place an order to close an open position for a product. This
    #'   is the idiomatic way to flatten a position -- e.g. the short leg of a
    #'   futures pair -- without hand-constructing an opposing order.
    #' @param product_id Character; the product whose position to close.
    #' @param size Character/numeric or NULL; the amount (contracts / base size)
    #'   to close. `NULL` closes the entire position.
    #' @param client_order_id Character; idempotency key. Defaults to a fresh
    #'   UUID via [generate_client_order_id()].
    #' @return A single-row [data.table::data.table] with `success`, the scalar
    #'   `order_id`, and flattened order details, or a promise thereof.
    close_position = function(product_id, size = NULL, client_order_id = generate_client_order_id()) {
      validate_symbol(product_id)
      assert::assert_scalar_character(client_order_id)
      size <- if (!is.null(size)) coerce_positive_string(size, "size") else NULL
      return(private$.request(
        endpoint = "/api/v3/brokerage/orders/close_position",
        method = "POST",
        body = list(client_order_id = client_order_id, product_id = product_id, size = size),
        auth = TRUE,
        .parser = parse_create_order
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
