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
    #' @param product_id (scalar<character>) e.g. `"BTC-USD"`.
    #' @param side (scalar<character>) `"BUY"` or `"SELL"`.
    #' @param order_configuration (list) the one-key order configuration.
    #' @param client_order_id (scalar<character>) idempotency key. Defaults to a
    #'   fresh UUID via [generate_client_order_id()].
    #' @param self_trade_prevention_id (scalar<character> | NULL)
    #'   self-trade-prevention group id. Optional.
    #' @param leverage (scalar<character> | NULL) leverage for the order (e.g.
    #'   `"2"`). Optional.
    #' @param margin_type (scalar<character> | NULL) `"CROSS"` or `"ISOLATED"`.
    #'   Optional.
    #' @param retail_portfolio_id (scalar<character> | NULL) portfolio to route the
    #'   order to. Optional.
    #' @return (CreateOrderAck | promise<CreateOrderAck>) a single-row
    #'   create-order acknowledgement, or a promise thereof.
    #' @noassert product_id, side, order_configuration
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
      assert_args_CoinbaseTrading__add_order(
        client_order_id,
        self_trade_prevention_id,
        leverage,
        margin_type,
        retail_portfolio_id
      )
      order_configuration <- stringify_order_config(order_configuration)
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
      res <- private$.request(
        endpoint = "/api/v3/brokerage/orders",
        method = "POST",
        body = body,
        auth = TRUE,
        .parser = parse_create_order
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseTrading__add_order,
        is_async = private$.is_async
      ))
    },

    #' @description Preview an order without placing it (dry run; executes
    #'   nothing). Returns the estimated total, commission, sizes, and any
    #'   validation errors.
    #' @param product_id (scalar<character>) e.g. `"BTC-USD"`.
    #' @param side (scalar<character>) `"BUY"` or `"SELL"`.
    #' @param order_configuration (list) the one-key order configuration.
    #' @param leverage (scalar<character> | NULL) leverage for the order. Optional.
    #' @param margin_type (scalar<character> | NULL) `"CROSS"` or `"ISOLATED"`.
    #'   Optional.
    #' @param retail_portfolio_id (scalar<character> | NULL) portfolio to scope the
    #'   preview to. Optional.
    #' @return (Preview | promise<Preview>) a single-row preview estimate, or a
    #'   promise thereof.
    #' @noassert product_id, side, order_configuration
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
      assert_args_CoinbaseTrading__preview_order(
        leverage,
        margin_type,
        retail_portfolio_id
      )
      order_configuration <- stringify_order_config(order_configuration)
      body <- list(
        product_id = product_id,
        side = side,
        order_configuration = order_configuration,
        leverage = leverage,
        margin_type = margin_type,
        retail_portfolio_id = retail_portfolio_id
      )
      res <- private$.request(
        endpoint = "/api/v3/brokerage/orders/preview",
        method = "POST",
        body = body,
        auth = TRUE,
        .parser = parse_preview
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseTrading__preview_order,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve a single order by its ID.
    #' @param order_id (scalar<character>) the order ID.
    #' @return (Orders | promise<Orders>) a single-row order table, or a promise
    #'   thereof.
    get_order = function(order_id) {
      assert_args_CoinbaseTrading__get_order(order_id)
      res <- private$.request(
        endpoint = paste0("/api/v3/brokerage/orders/historical/", order_id),
        auth = TRUE,
        .parser = function(b) parse_orders(list(b$order))
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseTrading__get_order,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve historical orders, paginating over the cursor.
    #' @param product_ids (character | NULL) filter by product(s).
    #' @param order_status (character | NULL) e.g. `"OPEN"`, `"FILLED"`,
    #'   `"CANCELLED"`.
    #' @param order_side (scalar<character> | NULL) `"BUY"` or `"SELL"`.
    #' @param limit (scalar<count in [1, Inf[> | NULL) page size.
    #' @param order_ids (character | NULL) filter by specific order id(s).
    #' @param start_date (scalar<character> | NULL) RFC 3339 lower bound on order
    #'   creation time.
    #' @param end_date (scalar<character> | NULL) RFC 3339 upper bound on order
    #'   creation time.
    #' @param order_types (character | NULL) e.g. `"LIMIT"`, `"MARKET"`.
    #' @param product_type (scalar<character> | NULL) `"SPOT"` or `"FUTURE"`.
    #' @param order_placement_source (scalar<character> | NULL) e.g.
    #'   `"RETAIL_ADVANCED"`.
    #' @param contract_expiry_type (scalar<character> | NULL) e.g. `"EXPIRING"`.
    #' @param asset_filters (character | NULL) filter by asset.
    #' @param retail_portfolio_id (scalar<character> | NULL) scope to a portfolio.
    #' @param time_in_forces (character | NULL) e.g. `"GOOD_UNTIL_CANCELLED"`.
    #' @param sort_by (scalar<character> | NULL) sort field, e.g.
    #'   `"LAST_FILL_TIME"`.
    #' @param max_pages (scalar<numeric in [1, Inf]>) cap on pages fetched.
    #'   Default `Inf`.
    #' @return (Orders | promise<Orders>) the orders, or a promise thereof.
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
      assert_args_CoinbaseTrading__get_orders(
        product_ids,
        order_status,
        order_side,
        limit,
        order_ids,
        start_date,
        end_date,
        order_types,
        product_type,
        order_placement_source,
        contract_expiry_type,
        asset_filters,
        retail_portfolio_id,
        time_in_forces,
        sort_by,
        max_pages
      )
      res <- coinbase_paginate_cursor(
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
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseTrading__get_orders,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve historical fills, paginating over the cursor.
    #' @param order_ids (character | NULL) filter by order id(s).
    #' @param trade_ids (character | NULL) filter by trade id(s).
    #' @param product_ids (character | NULL) filter by product(s).
    #' @param start_sequence_timestamp (scalar<character> | NULL) RFC 3339 lower
    #'   bound on fill sequence time.
    #' @param end_sequence_timestamp (scalar<character> | NULL) RFC 3339 upper
    #'   bound on fill sequence time.
    #' @param retail_portfolio_id (scalar<character> | NULL) scope to a portfolio.
    #' @param limit (scalar<count in [1, Inf[> | NULL) page size.
    #' @param sort_by (scalar<character> | NULL) sort field, e.g. `"TRADE_TIME"`.
    #' @param max_pages (scalar<numeric in [1, Inf]>) cap on pages fetched.
    #'   Default `Inf`.
    #' @return (Fills | promise<Fills>) the fills, or a promise thereof.
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
      assert_args_CoinbaseTrading__get_fills(
        order_ids,
        trade_ids,
        product_ids,
        start_sequence_timestamp,
        end_sequence_timestamp,
        retail_portfolio_id,
        limit,
        sort_by,
        max_pages
      )
      res <- coinbase_paginate_cursor(
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
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseTrading__get_fills,
        is_async = private$.is_async
      ))
    },

    #' @description Edit an open order's price and/or size.
    #' @param order_id (scalar<character>) the order ID.
    #' @param price (scalar<numeric> | scalar<character> | NULL) new limit price.
    #' @param size (scalar<numeric> | scalar<character> | NULL) new size.
    #' @return (EditOrderAck | promise<EditOrderAck>) a single-row edit
    #'   acknowledgement, or a promise thereof.
    #' @noassert price, size
    edit_order = function(order_id, price = NULL, size = NULL) {
      assert_args_CoinbaseTrading__edit_order(order_id)
      if (is.null(price) && is.null(size)) {
        rlang::abort("edit_order requires at least one of `price` or `size`.")
      }
      if (!is.null(price)) {
        price <- coerce_positive_string(price, "price")
      }
      if (!is.null(size)) {
        size <- coerce_positive_string(size, "size")
      }
      res <- private$.request(
        endpoint = "/api/v3/brokerage/orders/edit",
        method = "POST",
        body = list(order_id = order_id, price = price, size = size),
        auth = TRUE,
        .parser = parse_edit_order
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseTrading__edit_order,
        is_async = private$.is_async
      ))
    },

    #' @description Preview an order edit without applying it (dry run).
    #' @param order_id (scalar<character>) the order ID.
    #' @param price (scalar<numeric> | scalar<character> | NULL) proposed limit
    #'   price.
    #' @param size (scalar<numeric> | scalar<character> | NULL) proposed size.
    #' @return (EditPreview | promise<EditPreview>) a single-row edit-preview
    #'   estimate, or a promise thereof.
    #' @noassert price, size
    preview_edit_order = function(order_id, price = NULL, size = NULL) {
      assert_args_CoinbaseTrading__preview_edit_order(order_id)
      if (is.null(price) && is.null(size)) {
        rlang::abort("preview_edit_order requires at least one of `price` or `size`.")
      }
      if (!is.null(price)) {
        price <- coerce_positive_string(price, "price")
      }
      if (!is.null(size)) {
        size <- coerce_positive_string(size, "size")
      }
      res <- private$.request(
        endpoint = "/api/v3/brokerage/orders/edit_preview",
        method = "POST",
        body = list(order_id = order_id, price = price, size = size),
        auth = TRUE,
        .parser = parse_edit_preview
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseTrading__preview_edit_order,
        is_async = private$.is_async
      ))
    },

    #' @description Cancel one or more open orders.
    #' @param order_ids (character) the order IDs to cancel.
    #' @return (CancelResults | promise<CancelResults>) per-order cancel results,
    #'   or a promise thereof.
    cancel_orders = function(order_ids) {
      assert_args_CoinbaseTrading__cancel_orders(order_ids)
      if (length(order_ids) == 0L) {
        rlang::abort("`order_ids` must contain at least one order id.")
      }
      res <- private$.request(
        endpoint = "/api/v3/brokerage/orders/batch_cancel",
        method = "POST",
        body = list(order_ids = as.list(order_ids)),
        auth = TRUE,
        .parser = function(b) parse_cancel_results(b$results)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseTrading__cancel_orders,
        is_async = private$.is_async
      ))
    },

    #' @description Place an order to close an open position for a product. This
    #'   is the idiomatic way to flatten a position -- e.g. the short leg of a
    #'   futures pair -- without hand-constructing an opposing order.
    #' @param product_id (scalar<character>) the product whose position to close.
    #' @param size (scalar<numeric> | scalar<character> | NULL) the amount
    #'   (contracts / base size) to close. `NULL` closes the entire position.
    #' @param client_order_id (scalar<character>) idempotency key. Defaults to a
    #'   fresh UUID via [generate_client_order_id()].
    #' @return (CreateOrderAck | promise<CreateOrderAck>) a single-row
    #'   create-order acknowledgement, or a promise thereof.
    #' @noassert product_id, size
    close_position = function(product_id, size = NULL, client_order_id = generate_client_order_id()) {
      validate_symbol(product_id)
      assert_args_CoinbaseTrading__close_position(client_order_id)
      if (!is.null(size)) {
        size <- coerce_positive_string(size, "size")
      }
      res <- private$.request(
        endpoint = "/api/v3/brokerage/orders/close_position",
        method = "POST",
        body = list(client_order_id = client_order_id, product_id = product_id, size = size),
        auth = TRUE,
        .parser = parse_create_order
      )
      return(connectcore::then_or_now(
        res,
        assert_return_CoinbaseTrading__close_position,
        is_async = private$.is_async
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
