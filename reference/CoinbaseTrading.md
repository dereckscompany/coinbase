# CoinbaseTrading: Order Placement and Management

CoinbaseTrading: Order Placement and Management

CoinbaseTrading: Order Placement and Management

## Details

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

## Super classes

[`connectcore::RestClient`](https://rdrr.io/pkg/connectcore/man/RestClient.html)
-\>
[`coinbase::CoinbaseBase`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md)
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

- [`coinbase::CoinbaseBase$initialize()`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.html#method-initialize)

------------------------------------------------------------------------

### Method `add_order()`

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

  (scalar\<character\>) e.g. `"BTC-USD"`.

- `side`:

  (scalar\<character\>) `"BUY"` or `"SELL"`.

- `order_configuration`:

  (list) the one-key order configuration.

- `client_order_id`:

  (scalar\<character\>) idempotency key. Defaults to a fresh UUID via
  [`generate_client_order_id()`](https://dereckscompany.github.io/coinbase/reference/generate_client_order_id.md).

- `self_trade_prevention_id`:

  (scalar\<character\> \| NULL) self-trade-prevention group id.
  Optional.

- `leverage`:

  (scalar\<character\> \| NULL) leverage for the order (e.g. `"2"`).
  Optional.

- `margin_type`:

  (scalar\<character\> \| NULL) `"CROSS"` or `"ISOLATED"`. Optional.

- `retail_portfolio_id`:

  (scalar\<character\> \| NULL) portfolio to route the order to.
  Optional.

#### Returns

(CreateOrderAck \| promise\<CreateOrderAck\>) a single-row create-order
acknowledgement, or a promise thereof.

------------------------------------------------------------------------

### Method `preview_order()`

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

  (scalar\<character\>) e.g. `"BTC-USD"`.

- `side`:

  (scalar\<character\>) `"BUY"` or `"SELL"`.

- `order_configuration`:

  (list) the one-key order configuration.

- `leverage`:

  (scalar\<character\> \| NULL) leverage for the order. Optional.

- `margin_type`:

  (scalar\<character\> \| NULL) `"CROSS"` or `"ISOLATED"`. Optional.

- `retail_portfolio_id`:

  (scalar\<character\> \| NULL) portfolio to scope the preview to.
  Optional.

#### Returns

(Preview \| promise\<Preview\>) a single-row preview estimate, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_order()`

Retrieve a single order by its ID.

#### Usage

    CoinbaseTrading$get_order(order_id)

#### Arguments

- `order_id`:

  (scalar\<character\>) the order ID.

#### Returns

(Orders \| promise\<Orders\>) a single-row order table, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_orders()`

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

  (character \| NULL) filter by product(s).

- `order_status`:

  (character \| NULL) e.g. `"OPEN"`, `"FILLED"`, `"CANCELLED"`.

- `order_side`:

  (scalar\<character\> \| NULL) `"BUY"` or `"SELL"`.

- `limit`:

  (scalar\<count in \[1, Inf\[\> \| NULL) page size.

- `order_ids`:

  (character \| NULL) filter by specific order id(s).

- `start_date`:

  (scalar\<character\> \| NULL) RFC 3339 lower bound on order creation
  time.

- `end_date`:

  (scalar\<character\> \| NULL) RFC 3339 upper bound on order creation
  time.

- `order_types`:

  (character \| NULL) e.g. `"LIMIT"`, `"MARKET"`.

- `product_type`:

  (scalar\<character\> \| NULL) `"SPOT"` or `"FUTURE"`.

- `order_placement_source`:

  (scalar\<character\> \| NULL) e.g. `"RETAIL_ADVANCED"`.

- `contract_expiry_type`:

  (scalar\<character\> \| NULL) e.g. `"EXPIRING"`.

- `asset_filters`:

  (character \| NULL) filter by asset.

- `retail_portfolio_id`:

  (scalar\<character\> \| NULL) scope to a portfolio.

- `time_in_forces`:

  (character \| NULL) e.g. `"GOOD_UNTIL_CANCELLED"`.

- `sort_by`:

  (scalar\<character\> \| NULL) sort field, e.g. `"LAST_FILL_TIME"`.

- `max_pages`:

  (scalar\<numeric in \[1, Inf\]\>) cap on pages fetched. Default `Inf`.

#### Returns

(Orders \| promise\<Orders\>) the orders, or a promise thereof.

------------------------------------------------------------------------

### Method `get_fills()`

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

  (character \| NULL) filter by order id(s).

- `trade_ids`:

  (character \| NULL) filter by trade id(s).

- `product_ids`:

  (character \| NULL) filter by product(s).

- `start_sequence_timestamp`:

  (scalar\<character\> \| NULL) RFC 3339 lower bound on fill sequence
  time.

- `end_sequence_timestamp`:

  (scalar\<character\> \| NULL) RFC 3339 upper bound on fill sequence
  time.

- `retail_portfolio_id`:

  (scalar\<character\> \| NULL) scope to a portfolio.

- `limit`:

  (scalar\<count in \[1, Inf\[\> \| NULL) page size.

- `sort_by`:

  (scalar\<character\> \| NULL) sort field, e.g. `"TRADE_TIME"`.

- `max_pages`:

  (scalar\<numeric in \[1, Inf\]\>) cap on pages fetched. Default `Inf`.

#### Returns

(Fills \| promise\<Fills\>) the fills, or a promise thereof.

------------------------------------------------------------------------

### Method `edit_order()`

Edit an open order's price and/or size.

#### Usage

    CoinbaseTrading$edit_order(order_id, price = NULL, size = NULL)

#### Arguments

- `order_id`:

  (scalar\<character\>) the order ID.

- `price`:

  (scalar\<numeric\> \| scalar\<character\> \| NULL) new limit price.

- `size`:

  (scalar\<numeric\> \| scalar\<character\> \| NULL) new size.

#### Returns

(EditOrderAck \| promise\<EditOrderAck\>) a single-row edit
acknowledgement, or a promise thereof.

------------------------------------------------------------------------

### Method `preview_edit_order()`

Preview an order edit without applying it (dry run).

#### Usage

    CoinbaseTrading$preview_edit_order(order_id, price = NULL, size = NULL)

#### Arguments

- `order_id`:

  (scalar\<character\>) the order ID.

- `price`:

  (scalar\<numeric\> \| scalar\<character\> \| NULL) proposed limit
  price.

- `size`:

  (scalar\<numeric\> \| scalar\<character\> \| NULL) proposed size.

#### Returns

(EditPreview \| promise\<EditPreview\>) a single-row edit-preview
estimate, or a promise thereof.

------------------------------------------------------------------------

### Method `cancel_orders()`

Cancel one or more open orders.

#### Usage

    CoinbaseTrading$cancel_orders(order_ids)

#### Arguments

- `order_ids`:

  (character) the order IDs to cancel.

#### Returns

(CancelResults \| promise\<CancelResults\>) per-order cancel results, or
a promise thereof.

------------------------------------------------------------------------

### Method `close_position()`

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

  (scalar\<character\>) the product whose position to close.

- `size`:

  (scalar\<numeric\> \| scalar\<character\> \| NULL) the amount
  (contracts / base size) to close. `NULL` closes the entire position.

- `client_order_id`:

  (scalar\<character\>) idempotency key. Defaults to a fresh UUID via
  [`generate_client_order_id()`](https://dereckscompany.github.io/coinbase/reference/generate_client_order_id.md).

#### Returns

(CreateOrderAck \| promise\<CreateOrderAck\>) a single-row create-order
acknowledgement, or a promise thereof.

------------------------------------------------------------------------

### Method `clone()`

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
