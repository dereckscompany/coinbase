# CoinbaseTrading: Order Placement and Management

Places, previews, edits, cancels, and queries orders and fills on the
Coinbase Advanced Trade API. All endpoints require credentials.

Inherits from
[CoinbaseBase](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md).
All methods support both synchronous and asynchronous execution
depending on the `async` argument at construction.

### Order configuration

Orders carry an `order_configuration`: a one-key list naming the
detailed order type, e.g.

- `list(market_market_ioc = list(quote_size = "10"))` (market buy of
  \$10)

- `list(limit_limit_gtc = list(base_size = "0.001", limit_price = "50000"))`

- `list(stop_limit_stop_limit_gtc = list(base_size = ..., limit_price = ...,`
  `stop_price = ..., stop_direction = "STOP_DIRECTION_STOP_DOWN"))`

Use preview_order() (a dry run that places nothing) to validate a
configuration before submitting.

### Pagination

`get_orders()` and `get_fills()` walk the body-cursor pagination.

### Endpoints Covered

|                    |                                               |      |
|--------------------|-----------------------------------------------|------|
| Method             | Endpoint                                      | Auth |
| add_order          | POST /api/v3/brokerage/orders                 | Yes  |
| preview_order      | POST /api/v3/brokerage/orders/preview         | Yes  |
| get_order          | GET /api/v3/brokerage/orders/historical/{id}  | Yes  |
| get_orders         | GET /api/v3/brokerage/orders/historical/batch | Yes  |
| get_fills          | GET /api/v3/brokerage/orders/historical/fills | Yes  |
| edit_order         | POST /api/v3/brokerage/orders/edit            | Yes  |
| preview_edit_order | POST /api/v3/brokerage/orders/edit_preview    | Yes  |
| cancel_orders      | POST /api/v3/brokerage/orders/batch_cancel    | Yes  |

## Super class

[`CoinbaseBase`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md)
-\> `CoinbaseTrading`

## Methods

### Public methods

- [`CoinbaseTrading$add_order()`](#method-CoinbaseTrading-add_order)

- [`CoinbaseTrading$preview_order()`](#method-CoinbaseTrading-preview_order)

- [`CoinbaseTrading$get_order()`](#method-CoinbaseTrading-get_order)

- [`CoinbaseTrading$get_orders()`](#method-CoinbaseTrading-get_orders)

- [`CoinbaseTrading$get_fills()`](#method-CoinbaseTrading-get_fills)

- [`CoinbaseTrading$edit_order()`](#method-CoinbaseTrading-edit_order)

- [`CoinbaseTrading$preview_edit_order()`](#method-CoinbaseTrading-preview_edit_order)

- [`CoinbaseTrading$cancel_orders()`](#method-CoinbaseTrading-cancel_orders)

- [`CoinbaseTrading$close_position()`](#method-CoinbaseTrading-close_position)

- [`CoinbaseTrading$clone()`](#method-CoinbaseTrading-clone)

Inherited methods

- [`CoinbaseBase$initialize()`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.html#method-initialize)

------------------------------------------------------------------------

### `CoinbaseTrading$add_order()`

Place a new order. The order is live and may execute; use
`preview_order()` first to validate.

#### Usage

    CoinbaseTrading$add_order(
      product_id,
      side,
      order_configuration,
      client_order_id = generate_client_order_id(),
      self_trade_prevention_id = NULL,
      leverage = NULL,
      margin_type = NULL,
      retail_portfolio_id = NULL
    )

#### Arguments

- `product_id`:

  Character; e.g. `"BTC-USD"`.

- `side`:

  Character; `"BUY"` or `"SELL"`.

- `order_configuration`:

  Named list; the one-key order configuration.

- `client_order_id`:

  Character; idempotency key. Defaults to a fresh UUID via
  [`generate_client_order_id()`](https://dereckscompany.github.io/coinbase/reference/generate_client_order_id.md).

- `self_trade_prevention_id`:

  Character or NULL; self-trade-prevention group id. Optional.

- `leverage`:

  Character or NULL; leverage for the order (e.g. `"2"`). Optional.

- `margin_type`:

  Character or NULL; `"CROSS"` or `"ISOLATED"`. Optional.

- `retail_portfolio_id`:

  Character or NULL; portfolio to route the order to. Optional.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `success`, the scalar `order_id`, `product_id`, `side`,
`client_order_id`, `failure_reason`, and flattened order-configuration
columns, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseTrading$preview_order()`

Preview an order without placing it (dry run; executes nothing). Returns
the estimated total, commission, sizes, and any validation errors.

#### Usage

    CoinbaseTrading$preview_order(
      product_id,
      side,
      order_configuration,
      leverage = NULL,
      margin_type = NULL,
      retail_portfolio_id = NULL
    )

#### Arguments

- `product_id`:

  Character; e.g. `"BTC-USD"`.

- `side`:

  Character; `"BUY"` or `"SELL"`.

- `order_configuration`:

  Named list; the one-key order configuration.

- `leverage`:

  Character or NULL; leverage for the order. Optional.

- `margin_type`:

  Character or NULL; `"CROSS"` or `"ISOLATED"`. Optional.

- `retail_portfolio_id`:

  Character or NULL; portfolio to scope the preview to. Optional.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseTrading$get_order()`

Retrieve a single order by its ID.

#### Usage

    CoinbaseTrading$get_order(order_id)

#### Arguments

- `order_id`:

  Character; the order ID.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseTrading$get_orders()`

Retrieve historical orders, paginating over the cursor.

#### Usage

    CoinbaseTrading$get_orders(
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
    )

#### Arguments

- `product_ids`:

  Character vector or NULL; filter by product(s).

- `order_status`:

  Character vector or NULL; e.g. `"OPEN"`, `"FILLED"`, `"CANCELLED"`.

- `order_side`:

  Character or NULL; `"BUY"` or `"SELL"`.

- `limit`:

  Integer or NULL; page size.

- `order_ids`:

  Character vector or NULL; filter by specific order id(s).

- `start_date, end_date`:

  Character or NULL; RFC 3339 bounds on order creation time.

- `order_types`:

  Character vector or NULL; e.g. `"LIMIT"`, `"MARKET"`.

- `product_type`:

  Character or NULL; `"SPOT"` or `"FUTURE"`.

- `order_placement_source`:

  Character or NULL; e.g. `"RETAIL_ADVANCED"`.

- `contract_expiry_type`:

  Character or NULL; e.g. `"EXPIRING"`.

- `asset_filters`:

  Character vector or NULL; filter by asset.

- `retail_portfolio_id`:

  Character or NULL; scope to a portfolio.

- `time_in_forces`:

  Character vector or NULL; e.g. `"GOOD_UNTIL_CANCELLED"`.

- `sort_by`:

  Character or NULL; sort field, e.g. `"LAST_FILL_TIME"`.

- `max_pages`:

  Numeric; cap on pages fetched. Default `Inf`.

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of orders, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseTrading$get_fills()`

Retrieve historical fills, paginating over the cursor.

#### Usage

    CoinbaseTrading$get_fills(
      order_ids = NULL,
      trade_ids = NULL,
      product_ids = NULL,
      start_sequence_timestamp = NULL,
      end_sequence_timestamp = NULL,
      retail_portfolio_id = NULL,
      limit = NULL,
      sort_by = NULL,
      max_pages = Inf
    )

#### Arguments

- `order_ids`:

  Character vector or NULL; filter by order id(s).

- `trade_ids`:

  Character vector or NULL; filter by trade id(s).

- `product_ids`:

  Character vector or NULL; filter by product(s).

- `start_sequence_timestamp, end_sequence_timestamp`:

  Character or NULL; RFC 3339 bounds on fill sequence time.

- `retail_portfolio_id`:

  Character or NULL; scope to a portfolio.

- `limit`:

  Integer or NULL; page size.

- `sort_by`:

  Character or NULL; sort field, e.g. `"TRADE_TIME"`.

- `max_pages`:

  Numeric; cap on pages fetched. Default `Inf`.

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of fills, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseTrading$edit_order()`

Edit an open order's price and/or size.

#### Usage

    CoinbaseTrading$edit_order(order_id, price = NULL, size = NULL)

#### Arguments

- `order_id`:

  Character; the order ID.

- `price`:

  Character/numeric or NULL; new limit price.

- `size`:

  Character/numeric or NULL; new size.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseTrading$preview_edit_order()`

Preview an order edit without applying it (dry run).

#### Usage

    CoinbaseTrading$preview_edit_order(order_id, price = NULL, size = NULL)

#### Arguments

- `order_id`:

  Character; the order ID.

- `price`:

  Character/numeric or NULL; proposed limit price.

- `size`:

  Character/numeric or NULL; proposed size.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseTrading$cancel_orders()`

Cancel one or more open orders.

#### Usage

    CoinbaseTrading$cancel_orders(order_ids)

#### Arguments

- `order_ids`:

  Character vector; the order IDs to cancel.

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of per-order cancel results, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseTrading$close_position()`

Place an order to close an open position for a product. This is the
idiomatic way to flatten a position – e.g. the short leg of a futures
pair – without hand-constructing an opposing order.

#### Usage

    CoinbaseTrading$close_position(
      product_id,
      size = NULL,
      client_order_id = generate_client_order_id()
    )

#### Arguments

- `product_id`:

  Character; the product whose position to close.

- `size`:

  Character/numeric or NULL; the amount (contracts / base size) to
  close. `NULL` closes the entire position.

- `client_order_id`:

  Character; idempotency key. Defaults to a fresh UUID via
  [`generate_client_order_id()`](https://dereckscompany.github.io/coinbase/reference/generate_client_order_id.md).

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `success`, the scalar `order_id`, and flattened order details, or a
promise thereof.

------------------------------------------------------------------------

### `CoinbaseTrading$clone()`

The objects of this class are cloneable with this method.

#### Usage

    CoinbaseTrading$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
trading <- CoinbaseTrading$new()
# Validate without placing anything:
trading$preview_order("BTC-USD", "BUY", list(market_market_ioc = list(quote_size = "10")))
trading$get_orders(product_ids = "BTC-USD", limit = 10)
} # }
```
