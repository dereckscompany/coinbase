# Package Tour and Data-Shape Conventions

This vignette is the **one-stop tour** of the `coinbase` package. It
catalogues every public method by class, gives the exact `data.table`
each one returns — column names and types — and then documents the
underlying data-shape policy in detail.

If you’ve never used the package, read top to bottom. If you’ve used it
and just want to know how a specific endpoint comes back, jump to the
catalogue table for its class and then to the column listings below it.

The same conventions are shared with the sister `alpaca`, `binance`, and
`kucoin` packages, so that switching between exchanges does not mean
switching mental models of how the data looks. The defining invariant on
`coinbase` is the strongest of the four: **every method returns a
`data.table` with no list columns.** Coinbase’s nested
`{value, currency}` monetary amounts are flattened to plain numerics,
fixed-schema nested objects (`fee_tier`, `order_configuration`,
`margin_window`) are collapsed into scalar columns, and error arrays are
joined to a single string — so a returned table never hides a list cell.

Every example below is **live**: it runs against a built-in mock of the
Coinbase API, so the tables you see are exactly the shape the real
endpoints return.

------------------------------------------------------------------------

### What’s in the package

Four R6 classes plus a handful of standalone helpers wrap the Coinbase
Advanced Trade API (authenticated trading / account / futures) and the
public Coinbase Exchange API (market data). Every class supports both
**synchronous** and **asynchronous (promise-based)** operation via
`httr2`, selected by the `async` flag at construction. All four inherit
from a common abstract base (`CoinbaseBase`) that handles JWT signing,
sync/async dispatch, and body-cursor pagination.

| Class | What it covers |
|----|----|
| `CoinbaseMarketData` | Public market data on the Exchange host — products, candles (OHLCV), tick trades, deep trade history, order book, ticker, server time. No auth |
| `CoinbaseAccount` | Authenticated account data — trading accounts (balances), transaction/fee summary, portfolios, API-key permissions |
| `CoinbaseTrading` | Order management — place, preview, edit, edit-preview, cancel, and query orders + fills |
| `CoinbaseFutures` | US futures (Coinbase Financial Markets / CFM) — balance summary, positions, cash sweeps, intraday margin settings, margin window |

Standalone (not on a class):

| Helper | What it does |
|----|----|
| [`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md), [`get_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_base_url.md), [`get_exchange_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_exchange_base_url.md) | Read API credentials and base URLs from environment variables |
| [`coinbase_build_request()`](https://dereckscompany.github.io/coinbase/reference/coinbase_build_request.md) | Low-level HTTP / JWT-signing primitive — every method goes through this |
| [`coinbase_backfill_trades()`](https://dereckscompany.github.io/coinbase/reference/coinbase_backfill_trades.md) | Bulk deep tick-history download for many products with CSV resume |
| [`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md) | Aggregate raw tick trades into OHLCV bars at any interval |
| [`verify_symbol()`](https://dereckscompany.github.io/coinbase/reference/verify_symbol.md) | Sanity-check a product ID’s shape before placing an order |
| [`generate_client_order_id()`](https://dereckscompany.github.io/coinbase/reference/generate_client_order_id.md) | Fresh RFC-4122 v4 UUID for the `client_order_id` idempotency key |

------------------------------------------------------------------------

### Setup

Coinbase Advanced Trade uses CDP key-pair credentials (a key `name` plus
a `privateKey`), not an API key / secret pair. Download the JSON from
<https://www.coinbase.com/settings/api> and store the two fields in
`.Renviron`. The multi-line `privateKey` is escaped onto one line by
replacing real newlines with the two characters `\n`;
[`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)
unescapes them back before signing.

``` bash
COINBASE_API_KEY_NAME=organizations/<org-uuid>/apiKeys/<key-uuid>
COINBASE_API_PRIVATE_KEY=-----BEGIN EC PRIVATE KEY-----\n<...base64...>\n-----END EC PRIVATE KEY-----\n
```

The placeholders above are deliberately fake; never commit a real key.
Both EC keys (ES256) and base64 Ed25519 keys (EdDSA) are supported by
the signer.

Then in R, using [`box::use`](https://klmr.me/box/reference/use.html)
rather than [`library()`](https://rdrr.io/r/base/library.html). When the
environment variables are set,
[`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)
reads them with no arguments:

``` r

box::use(
  coinbase[
    CoinbaseMarketData, CoinbaseAccount, CoinbaseTrading,
    CoinbaseFutures, get_api_keys
  ]
)

keys    <- get_api_keys()                 # reads .Renviron
market  <- CoinbaseMarketData$new()       # public, no keys needed
account <- CoinbaseAccount$new(keys = keys)
trading <- CoinbaseTrading$new(keys = keys)
futures <- CoinbaseFutures$new(keys = keys)
```

------------------------------------------------------------------------

### `CoinbaseMarketData` — public market data (Exchange host)

These endpoints hit the Exchange host (`api.exchange.coinbase.com`),
require no authentication, and expose deep trade history. The `/candles`
endpoint returns only ~300 bars per call, so complete OHLCV at any
timeframe is built from ticks: page `get_trades_history()` (or run
[`coinbase_backfill_trades()`](https://dereckscompany.github.io/coinbase/reference/coinbase_backfill_trades.md)),
then aggregate with
[`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md).

| Method | Endpoint | Shape |
|----|----|----|
| `get_products()` | `GET /products` | one row per product |
| `get_product(product_id)` | `GET /products/{id}` | single row |
| `get_ohlcv(product_id, granularity, start, end)` | `GET /products/{id}/candles` | one row per candle |
| `get_trades(product_id, limit, after)` | `GET /products/{id}/trades` | one row per trade |
| `get_trades_history(product_id, start, end, max_pages)` | `GET /products/{id}/trades` (paged) | one row per trade, sorted ascending, de-duplicated |
| `get_orderbook(product_id, level)` | `GET /products/{id}/book` | long — one row per `(side, level)` |
| `get_ticker(product_id)` | `GET /products/{id}/ticker` | single row |
| `get_server_time()` | `GET /time` | single row |

Public market data needs no keys:

``` r

market <- CoinbaseMarketData$new()
```

#### Products

`get_products()` and `get_product()` go through the generic `as_dt_list`
/ `as_dt_row` flatteners: every scalar field becomes a column, and any
nested object or multi-element value the API returns is collapsed to a
single JSON string (never a list column). Field names are snake_case.
Numeric-looking fields are returned as the character strings Coinbase
sends — cast at the point of use.

``` r

products <- market$get_products()
products[]
```

    #>         id base_currency quote_currency quote_increment base_increment
    #>     <char>        <char>         <char>          <char>         <char>
    #> 1: BTC-USD           BTC            USD            0.01     0.00000001
    #> 2: ETH-USD           ETH            USD            0.01     0.00000001
    #> 3: SOL-USD           SOL            USD            0.01     0.00000001
    #>    display_name min_market_funds margin_enabled post_only limit_only
    #>          <char>           <char>         <lgcl>    <lgcl>     <lgcl>
    #> 1:      BTC-USD                1          FALSE     FALSE      FALSE
    #> 2:      ETH-USD                1          FALSE     FALSE      FALSE
    #> 3:      SOL-USD                1          FALSE     FALSE      FALSE
    #>    cancel_only status status_message trading_disabled fx_stablecoin
    #>         <lgcl> <char>         <char>           <lgcl>        <lgcl>
    #> 1:       FALSE online                           FALSE         FALSE
    #> 2:       FALSE online                           FALSE         FALSE
    #> 3:       FALSE online                           FALSE         FALSE
    #>    max_slippage_percentage auction_mode high_bid_limit_percentage
    #>                     <char>       <lgcl>                    <char>
    #> 1:              0.02000000        FALSE                          
    #> 2:              0.02000000        FALSE                          
    #> 3:              0.02000000        FALSE

A single product is the same row shape:

``` r

market$get_product("BTC-USD")[]
```

    #>         id base_currency quote_currency quote_increment base_increment
    #>     <char>        <char>         <char>          <char>         <char>
    #> 1: BTC-USD           BTC            USD            0.01     0.00000001
    #>    display_name min_market_funds margin_enabled post_only limit_only
    #>          <char>           <char>         <lgcl>    <lgcl>     <lgcl>
    #> 1:      BTC-USD                1          FALSE     FALSE      FALSE
    #>    cancel_only status status_message trading_disabled fx_stablecoin
    #>         <lgcl> <char>         <char>           <lgcl>        <lgcl>
    #> 1:       FALSE online                           FALSE         FALSE
    #>    max_slippage_percentage auction_mode high_bid_limit_percentage
    #>                     <char>       <lgcl>                    <char>
    #> 1:              0.02000000        FALSE

#### OHLCV / candles

`get_ohlcv()` (parser `parse_candles`) reorders Coinbase’s raw
`[time, low, high, open, close, volume]` array into the canonical layout
and sorts ascending. Exactly six columns:

| Column     | Type            | Notes                         |
|------------|-----------------|-------------------------------|
| `datetime` | `POSIXct` (UTC) | bar start; from epoch seconds |
| `open`     | `numeric`       |                               |
| `high`     | `numeric`       |                               |
| `low`      | `numeric`       |                               |
| `close`    | `numeric`       |                               |
| `volume`   | `numeric`       |                               |

``` r

candles <- market$get_ohlcv("BTC-USD", granularity = "1min")
candles[, .(datetime, open, high, low, close, volume)]
```

    #>               datetime     open     high      low    close volume
    #>                 <POSc>    <num>    <num>    <num>    <num>  <num>
    #> 1: 2026-05-31 04:53:00 74055.40 74070.12 74050.00 74067.15 1.4820
    #> 2: 2026-05-31 04:54:00 74113.49 74113.49 74067.15 74068.26 3.0535
    #> 3: 2026-05-31 04:55:00 74068.26 74093.61 74068.26 74093.60 0.9691
    #> 4: 2026-05-31 04:56:00 74093.60 74099.83 74093.59 74099.83 0.1151

`granularity` is one of `"1min"`, `"5min"`, `"15min"`, `"1hour"`,
`"6hour"`, `"1day"`.

#### Trades

`get_trades()` and `get_trades_history()` (parser `parse_trades`) return
one row per tick trade, with exactly five typed columns:

| Column     | Type            | Notes |
|------------|-----------------|-------|
| `trade_id` | `numeric`       |       |
| `side`     | `character`     |       |
| `price`    | `numeric`       |       |
| `size`     | `numeric`       |       |
| `time`     | `POSIXct` (UTC) |       |

``` r

trades <- market$get_trades("BTC-USD", limit = 1000L)
trades[]
```

    #>      trade_id   side    price       size                time
    #>         <num> <char>    <num>      <num>              <POSc>
    #> 1: 1026942323   sell 74101.53 0.00000052 2026-05-31 04:58:29
    #> 2: 1026942322   sell 74101.53 0.00000240 2026-05-31 04:58:29
    #> 3: 1026942321    buy 74101.54 0.00058315 2026-05-31 04:58:29
    #> 4: 1026942320    buy 74100.98 0.01200000 2026-05-31 04:58:28

To page deeper into history with `get_trades()`, pass the smallest
`trade_id` seen so far as `after`; `get_trades_history()` does this loop
for you and returns a single de-duplicated, ascending table:

``` r

ticks <- market$get_trades_history("BTC-USD")
ticks[]
```

    #>      trade_id   side    price       size                time
    #>         <num> <char>    <num>      <num>              <POSc>
    #> 1: 1026942320    buy 74100.98 0.01200000 2026-05-31 04:58:28
    #> 2: 1026942321    buy 74101.54 0.00058315 2026-05-31 04:58:29
    #> 3: 1026942322   sell 74101.53 0.00000240 2026-05-31 04:58:29
    #> 4: 1026942323   sell 74101.53 0.00000052 2026-05-31 04:58:29

#### Order book

`get_orderbook()` (parser `parse_orderbook`) is the one **long-format**
market-data method: the `bids` and `asks` arrays are stacked into one
table with a `side` column (`"bid"` / `"ask"`). The shape of the third
column depends on the requested `level`:

| Column       | Type        | Levels                                 |
|--------------|-------------|----------------------------------------|
| `side`       | `character` | all — `"bid"` / `"ask"`                |
| `price`      | `numeric`   | all                                    |
| `size`       | `numeric`   | all                                    |
| `num_orders` | `numeric`   | levels **1 and 2** (aggregated book)   |
| `order_id`   | `character` | level **3** only (non-aggregated book) |

At levels 1 and 2 the book is aggregated, so each entry’s third element
is an order *count* (`num_orders`). At level 3 the book is the full
non-aggregated book, so the third element is an `order_id` string; the
parser emits it as a character `order_id` column instead of coercing it
to numeric. A given call returns one or the other, never both.

``` r

# Top 5 highest-priced asks (aggregated level-2 book)
depth <- market$get_orderbook("BTC-USD", level = 2L)
depth[side == "ask"][order(-price)][1:min(5, .N)]
```

    #>      side    price       size num_orders
    #>    <char>    <num>      <num>      <num>
    #> 1:    ask 74103.66 0.00140588          2
    #> 2:    ask 74103.63 0.26058806          2
    #> 3:    ask 74101.53 0.08631688          7

At level 3 the third column is a character `order_id` instead of
`num_orders` (a single call returns one or the other, never both):

``` r

l3 <- market$get_orderbook("BTC-USD", level = 3L)
l3[, .(side, price, size, order_id)]
```

    #>      side    price       size                             order_id
    #>    <char>    <num>      <num>                               <char>
    #> 1:    bid 74101.52 0.21000000 b1a2c3d4-0001-4aaa-8bbb-000000000001
    #> 2:    bid 74101.52 0.22541938 b1a2c3d4-0002-4aaa-8bbb-000000000002
    #> 3:    bid 74098.69 0.00266800 b1a2c3d4-0003-4aaa-8bbb-000000000003
    #> 4:    ask 74101.53 0.04000000 a1a2c3d4-0001-4aaa-8bbb-000000000001
    #> 5:    ask 74101.53 0.04631688 a1a2c3d4-0002-4aaa-8bbb-000000000002
    #> 6:    ask 74103.66 0.00140588 a1a2c3d4-0003-4aaa-8bbb-000000000003

#### Ticker and server time

`get_ticker()` returns a single row; the numeric fields (`ask`, `bid`,
`price`, `size`, `volume`, `rfq_volume` where present) are cast to
`numeric` and `time` to `POSIXct`, with any other fields (e.g.
`trade_id`) left as the API sends them.

``` r

market$get_ticker("BTC-USD")[]
```

    #>         ask      bid   volume   trade_id    price    size                time
    #>       <num>    <num>    <num>      <int>    <num>   <num>              <POSc>
    #> 1: 74101.53 74101.52 3600.231 1026942323 74101.53 5.2e-07 2026-05-31 04:58:29
    #>    rfq_volume
    #>         <num>
    #> 1:    10.7929

`get_server_time()` returns a single row with `iso` and `epoch`:

``` r

market$get_server_time()[]
```

    #>                         iso      epoch
    #>                      <char>      <num>
    #> 1: 2026-05-31T04:58:31.547Z 1780203512

------------------------------------------------------------------------

### `CoinbaseAccount` — accounts, fees, portfolios, permissions

All endpoints require credentials. `get_accounts()` walks Coinbase’s
body-cursor pagination (`cursor` / `has_next`) to return every account
across pages.

| Method | Endpoint | Shape |
|----|----|----|
| `get_accounts(limit, max_pages)` | `GET /api/v3/brokerage/accounts` | one row per account |
| `get_account(account_uuid)` | `GET /api/v3/brokerage/accounts/{uuid}` | single row |
| `get_fees(product_type)` | `GET /api/v3/brokerage/transaction_summary` | single row |
| `get_portfolios()` | `GET /api/v3/brokerage/portfolios` | one row per portfolio |
| `get_key_permissions()` | `GET /api/v3/brokerage/key_permissions` | single row |

Construct the authenticated client with your keys:

``` r

account <- CoinbaseAccount$new()
```

#### Accounts

`get_accounts()` / `get_account()` (parser `parse_accounts`) flatten the
nested `available_balance` / `hold` `{value, currency}` objects to plain
numerics. Exactly these columns:

| Column                | Type                                           |
|-----------------------|------------------------------------------------|
| `uuid`                | `character`                                    |
| `name`                | `character`                                    |
| `currency`            | `character`                                    |
| `available_balance`   | `numeric` (flattened from `{value, currency}`) |
| `hold`                | `numeric` (flattened from `{value, currency}`) |
| `active`              | `logical`                                      |
| `default`             | `logical`                                      |
| `ready`               | `logical`                                      |
| `type`                | `character`                                    |
| `platform`            | `character`                                    |
| `retail_portfolio_id` | `character`                                    |
| `created_at`          | `POSIXct` (UTC)                                |
| `updated_at`          | `POSIXct` (UTC)                                |

``` r

accts <- account$get_accounts()
accts[]
accts[available_balance > 0, .(currency, available_balance, hold)]
```

    #>                                    uuid       name currency available_balance
    #>                                  <char>     <char>   <char>             <num>
    #> 1: 8bfc20d7-f7c6-4422-bf07-8243ca4169fe BTC Wallet      BTC            0.5321
    #> 2: 1a2b3c4d-5e6f-4789-90ab-cdef01234567 USD Wallet      USD        12500.4200
    #>     hold active default  ready                type                  platform
    #>    <num> <lgcl>  <lgcl> <lgcl>              <char>                    <char>
    #> 1:     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO ACCOUNT_PLATFORM_CONSUMER
    #> 2:   250   TRUE    TRUE   TRUE   ACCOUNT_TYPE_FIAT ACCOUNT_PLATFORM_CONSUMER
    #>                     retail_portfolio_id          created_at          updated_at
    #>                                  <char>              <POSc>              <POSc>
    #> 1: 9c2f8b1e-1111-4d3a-9aaa-0123456789ab 2024-01-10 10:00:00 2026-05-30 18:40:29
    #> 2: 9c2f8b1e-1111-4d3a-9aaa-0123456789ab 2024-01-10 10:00:00 2026-05-30 18:40:29
    #>    currency available_balance  hold
    #>      <char>             <num> <num>
    #> 1:      BTC            0.5321     0
    #> 2:      USD        12500.4200   250

#### Fees

`get_fees()` (parser `parse_fees`) flattens the nested `fee_tier` object
into scalar columns alongside the top-level volume/fee fields. A single
row, every column numeric except `pricing_tier`:

| Column           | Type        |
|------------------|-------------|
| `pricing_tier`   | `character` |
| `maker_fee_rate` | `numeric`   |
| `taker_fee_rate` | `numeric`   |
| `usd_from`       | `numeric`   |
| `usd_to`         | `numeric`   |
| `total_volume`   | `numeric`   |
| `total_fees`     | `numeric`   |
| `total_balance`  | `numeric`   |

``` r

account$get_fees()[]
```

    #>    pricing_tier maker_fee_rate taker_fee_rate usd_from usd_to total_volume
    #>          <char>          <num>          <num>    <num>  <num>        <num>
    #> 1:   Advanced 1          0.004          0.006        0   1000     125000.5
    #>    total_fees total_balance
    #>         <num>         <num>
    #> 1:     312.75      13050.42

Pass `product_type = "SPOT"` or `"FUTURE"` to scope the summary.

#### Portfolios and key permissions

`get_portfolios()` returns one row per portfolio via the generic
`as_dt_list` flattener; `get_key_permissions()` returns a single row via
`as_dt_row`:

``` r

account$get_portfolios()[]
account$get_key_permissions()[]
```

    #>       name                                 uuid     type
    #>     <char>                               <char>   <char>
    #> 1: Default 9c2f8b1e-1111-4d3a-9aaa-0123456789ab  DEFAULT
    #> 2:    Algo 7d6e5f4c-2222-4b1a-8ccc-fedcba987654 CONSUMER
    #>    can_view can_trade can_transfer                       portfolio_uuid
    #>      <lgcl>    <lgcl>       <lgcl>                               <char>
    #> 1:     TRUE      TRUE        FALSE 9c2f8b1e-1111-4d3a-9aaa-0123456789ab
    #>    portfolio_type
    #>            <char>
    #> 1:        DEFAULT

------------------------------------------------------------------------

### `CoinbaseTrading` — order management

All endpoints require credentials. `get_orders()` and `get_fills()` walk
the body-cursor pagination. Orders carry an `order_configuration` — a
one-key list naming the detailed order type (e.g. `market_market_ioc`,
`limit_limit_gtc`, `stop_limit_stop_limit_gtc`) — which the parsers
flatten into scalar columns (see Treatment C below).

| Method | Endpoint | Shape |
|----|----|----|
| `add_order(product_id, side, order_configuration, client_order_id, self_trade_prevention_id, leverage, margin_type, retail_portfolio_id)` | `POST /api/v3/brokerage/orders` | single row |
| `preview_order(product_id, side, order_configuration, leverage, margin_type, retail_portfolio_id)` | `POST /api/v3/brokerage/orders/preview` | single row |
| `get_order(order_id)` | `GET /api/v3/brokerage/orders/historical/{id}` | single row |
| `get_orders(product_ids, order_status, order_side, limit, order_ids, start_date, end_date, order_types, product_type, order_placement_source, contract_expiry_type, asset_filters, retail_portfolio_id, time_in_forces, sort_by, max_pages)` | `GET /api/v3/brokerage/orders/historical/batch` | one row per order |
| `get_fills(order_ids, trade_ids, product_ids, start_sequence_timestamp, end_sequence_timestamp, retail_portfolio_id, limit, sort_by, max_pages)` | `GET /api/v3/brokerage/orders/historical/fills` | one row per fill |
| `edit_order(order_id, price, size)` | `POST /api/v3/brokerage/orders/edit` | single row |
| `preview_edit_order(order_id, price, size)` | `POST /api/v3/brokerage/orders/edit_preview` | single row |
| `cancel_orders(order_ids)` | `POST /api/v3/brokerage/orders/batch_cancel` | one row per order |

Note the recently-widened signatures: `add_order()` / `preview_order()`
take `leverage`, `margin_type` (`"CROSS"` / `"ISOLATED"`), and
`retail_portfolio_id` (plus `self_trade_prevention_id` on `add_order`
only); `get_orders()` takes the full filter set above; and `get_fills()`
filters by `order_ids` (**plural**) and `trade_ids`, with
sequence-timestamp bounds and a `sort_by`.

``` r

trading <- CoinbaseTrading$new()
```

#### Orders (`get_order` / `get_orders`)

Parser `parse_orders`, which flattens each order’s `order_configuration`
via `flatten_order_config`. Exactly these columns, one row per order:

| Column | Type | Notes |
|----|----|----|
| `order_id` | `character` |  |
| `client_order_id` | `character` |  |
| `product_id` | `character` |  |
| `side` | `character` |  |
| `status` | `character` |  |
| `order_type` | `character` | coarse API enum, e.g. `"LIMIT"` |
| `config_type` | `character` | detailed config key, e.g. `"limit_limit_gtc"` |
| `time_in_force` | `character` |  |
| `created_time` | `POSIXct` (UTC) |  |
| `completion_percentage` | `numeric` |  |
| `filled_size` | `numeric` |  |
| `average_filled_price` | `numeric` |  |
| `number_of_fills` | `numeric` |  |
| `filled_value` | `numeric` |  |
| `total_fees` | `numeric` |  |
| `base_size` | `numeric` | from `order_configuration` |
| `quote_size` | `numeric` | from `order_configuration` |
| `limit_price` | `numeric` | from `order_configuration` |
| `stop_price` | `numeric` | from `order_configuration` |
| `stop_trigger_price` | `numeric` | bracket trigger; from `order_configuration` |
| `stop_direction` | `character` | from `order_configuration` |
| `end_time` | `POSIXct` (UTC) | GTD expiry; from `order_configuration` |
| `post_only` | `logical` | from `order_configuration` |

``` r

orders <- trading$get_orders(product_ids = "BTC-USD", limit = 50L)
orders[, .(order_id, product_id, side, status, order_type, config_type, filled_size)]
```

    #>                                order_id product_id   side status order_type
    #>                                  <char>     <char> <char> <char>     <char>
    #> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc    BTC-USD    BUY   OPEN      LIMIT
    #> 2: 4444dddd-5555-eeee-6666-ffffffffffff    ETH-USD   SELL FILLED     MARKET
    #>          config_type filled_size
    #>               <char>       <num>
    #> 1:   limit_limit_gtc         0.0
    #> 2: market_market_ioc         0.5

A single order by id is the same row shape:

``` r

trading$get_order("1111aaaa-2222-bbbb-3333-cccccccccccc")[
  , .(order_id, side, status, config_type, base_size, limit_price)
]
```

    #>                                order_id   side status     config_type base_size
    #>                                  <char> <char> <char>          <char>     <num>
    #> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc    BUY   OPEN limit_limit_gtc     0.001
    #>    limit_price
    #>          <num>
    #> 1:       70000

#### Fills (`get_fills`)

Parser `parse_fills`, one row per fill, exactly:

| Column                | Type            |
|-----------------------|-----------------|
| `entry_id`            | `character`     |
| `trade_id`            | `character`     |
| `order_id`            | `character`     |
| `product_id`          | `character`     |
| `side`                | `character`     |
| `trade_time`          | `POSIXct` (UTC) |
| `trade_type`          | `character`     |
| `price`               | `numeric`       |
| `size`                | `numeric`       |
| `commission`          | `numeric`       |
| `size_in_quote`       | `logical`       |
| `liquidity_indicator` | `character`     |

``` r

fills <- trading$get_fills(product_ids = "BTC-USD", sort_by = "TRADE_TIME")
fills[]
```

    #>      entry_id   trade_id                             order_id product_id   side
    #>        <char>     <char>                               <char>     <char> <char>
    #> 1: entry-0001 trade-0001 4444dddd-5555-eeee-6666-ffffffffffff    ETH-USD   SELL
    #> 2: entry-0002 trade-0002 4444dddd-5555-eeee-6666-ffffffffffff    ETH-USD   SELL
    #>             trade_time trade_type  price  size commission size_in_quote
    #>                 <POSc>     <char>  <num> <num>      <num>        <lgcl>
    #> 1: 2026-05-30 18:31:02       FILL 3850.2   0.3       4.62         FALSE
    #> 2: 2026-05-30 18:31:03       FILL 3850.2   0.2       3.08         FALSE
    #>    liquidity_indicator
    #>                 <char>
    #> 1:               TAKER
    #> 2:               TAKER

#### Preview (`preview_order`)

Parser `parse_preview`, a single row. `errs` collapses Coinbase’s error
array (objects or bare strings) into one human-readable string — `NA`
when the preview validated cleanly.

| Column             | Type                                  |
|--------------------|---------------------------------------|
| `order_total`      | `numeric`                             |
| `commission_total` | `numeric`                             |
| `quote_size`       | `numeric`                             |
| `base_size`        | `numeric`                             |
| `best_bid`         | `numeric`                             |
| `best_ask`         | `numeric`                             |
| `slippage`         | `numeric`                             |
| `errs`             | `character` (collapsed; `NA` if none) |
| `preview_id`       | `character`                           |

``` r

# Validate without placing anything (dry run; executes nothing)
pv <- trading$preview_order(
  "BTC-USD", "BUY",
  list(market_market_ioc = list(quote_size = "10"))
)
pv[]
```

    #>    order_total commission_total quote_size base_size best_bid best_ask slippage
    #>          <num>            <num>      <num>     <num>    <num>    <num>    <num>
    #> 1:       10.06             0.06         10  0.000135 74101.52 74101.53    1e-04
    #>      errs          preview_id
    #>    <char>              <char>
    #> 1:   <NA> prev-1234-5678-90ab

#### Create-order (`add_order`)

Parser `parse_create_order`, a single row. The scalar `order_id` is
lifted out of the nested `success_response`, the failure/error objects
are collapsed to one `failure_reason` string, and the
`order_configuration` is flattened:

| Column               | Type                                     |
|----------------------|------------------------------------------|
| `success`            | `logical`                                |
| `order_id`           | `character`                              |
| `product_id`         | `character`                              |
| `side`               | `character`                              |
| `client_order_id`    | `character`                              |
| `failure_reason`     | `character` (collapsed; `NA` on success) |
| `config_type`        | `character`                              |
| `base_size`          | `numeric`                                |
| `quote_size`         | `numeric`                                |
| `limit_price`        | `numeric`                                |
| `stop_price`         | `numeric`                                |
| `stop_trigger_price` | `numeric`                                |

``` r

order <- trading$add_order(
  "BTC-USD", "BUY",
  list(market_market_ioc = list(quote_size = "10")),
  client_order_id = "client-001"
)
order[, .(success, order_id, product_id, side, client_order_id, failure_reason)]
```

    #>    success                             order_id product_id   side
    #>     <lgcl>                               <char>     <char> <char>
    #> 1:    TRUE 1111aaaa-2222-bbbb-3333-cccccccccccc    BTC-USD    BUY
    #>    client_order_id failure_reason
    #>             <char>         <char>
    #> 1:      client-001           <NA>

#### Edit, edit-preview, and cancel

| Method | Parser | Columns |
|----|----|----|
| `edit_order()` | `parse_edit_order` | `success` (logical), `order_id` (character), `errors` (collapsed character) |
| `preview_edit_order()` | `parse_edit_preview` | `errors` (collapsed character), then numerics `slippage`, `order_total`, `commission_total`, `quote_size`, `base_size`, `best_bid`, `average_filled_price` |
| `cancel_orders()` | `parse_cancel_results` | one row per order: `order_id` (character), `success` (logical), `failure_reason` (collapsed character) |

`edit_order()` / `preview_edit_order()` require at least one of `price`
or `size`. `cancel_orders()` takes a character vector of `order_ids`.

``` r

trading$edit_order("1111aaaa-2222-bbbb-3333-cccccccccccc", price = 71000)[]
```

    #>    success                             order_id errors
    #>     <lgcl>                               <char> <char>
    #> 1:    TRUE 1111aaaa-2222-bbbb-3333-cccccccccccc   <NA>

``` r

trading$preview_edit_order("1111aaaa-2222-bbbb-3333-cccccccccccc", price = 71000)[]
```

    #>    errors slippage order_total commission_total quote_size base_size best_bid
    #>    <char>    <num>       <num>            <num>      <num>     <num>    <num>
    #> 1:   <NA>    2e-04       70.07             0.07         70     0.001 74101.52
    #>    average_filled_price
    #>                   <num>
    #> 1:                    0

``` r

trading$cancel_orders(c("1111aaaa-2222-bbbb-3333-cccccccccccc"))[]
```

    #>                                order_id success                failure_reason
    #>                                  <char>  <lgcl>                        <char>
    #> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc    TRUE UNKNOWN_CANCEL_FAILURE_REASON

------------------------------------------------------------------------

### `CoinbaseFutures` — US futures (CFM)

All endpoints require credentials and a funded, approved CFM futures
account. Futures **orders are placed through the same order endpoint as
spot** — use `CoinbaseTrading$add_order()` with a futures `product_id`
(e.g. `"BIT-31OCT26-CDE"`) and a futures order configuration; this class
manages the surrounding account state only. Coinbase’s INTX perpetual
endpoints (non-US) are intentionally not wrapped.

| Method | Endpoint | Shape |
|----|----|----|
| `get_balance_summary()` | `GET /api/v3/brokerage/cfm/balance_summary` | single row |
| `get_positions()` | `GET /api/v3/brokerage/cfm/positions` | one row per position |
| `get_position(product_id)` | `GET /api/v3/brokerage/cfm/positions/{id}` | single row |
| `schedule_sweep(usd_amount)` | `POST /api/v3/brokerage/cfm/sweeps/schedule` | single row |
| `get_sweeps()` | `GET /api/v3/brokerage/cfm/sweeps` | one row per sweep |
| `cancel_sweep()` | `DELETE /api/v3/brokerage/cfm/sweeps` | single row |
| `get_intraday_margin_setting()` | `GET /api/v3/brokerage/cfm/intraday/margin_setting` | single row |
| `set_intraday_margin_setting(setting)` | `POST /api/v3/brokerage/cfm/intraday/margin_setting` | single row (echoes `setting`) |
| `get_current_margin_window(margin_profile_type)` | `GET /api/v3/brokerage/cfm/intraday/current_margin_window` | single row |

``` r

futures <- CoinbaseFutures$new()
```

#### Balance summary

Parser `parse_futures_balance`. Every monetary field is a nested
`{value, currency}` object on the wire, flattened here to `numeric` via
`flex_num` (which accepts either a scalar or a `{value, currency}`
object). A single row:

| Column | Type |
|----|----|
| `futures_buying_power` | `numeric` |
| `total_usd_balance` | `numeric` |
| `cbi_usd_balance` | `numeric` |
| `cfm_usd_balance` | `numeric` |
| `total_open_orders_hold_amount` | `numeric` |
| `unrealized_pnl` | `numeric` |
| `daily_realized_pnl` | `numeric` |
| `initial_margin` | `numeric` |
| `available_margin` | `numeric` |
| `liquidation_threshold` | `numeric` |
| `liquidation_buffer_amount` | `numeric` |
| `liquidation_buffer_percentage` | `numeric` (plain scalar, not `{value, currency}`) |

``` r

futures$get_balance_summary()[]
```

    #>    futures_buying_power total_usd_balance cbi_usd_balance cfm_usd_balance
    #>                   <num>             <num>           <num>           <num>
    #> 1:                 9500             10000            2000            8000
    #>    total_open_orders_hold_amount unrealized_pnl daily_realized_pnl
    #>                            <num>          <num>              <num>
    #> 1:                             0         -125.4               42.1
    #>    initial_margin available_margin liquidation_threshold
    #>             <num>            <num>                 <num>
    #> 1:            740             7260                   370
    #>    liquidation_buffer_amount liquidation_buffer_percentage
    #>                        <num>                         <num>
    #> 1:                      7630                          95.4

#### Positions

Parser `parse_futures_positions`, one row per open position:

| Column                | Type                  |
|-----------------------|-----------------------|
| `product_id`          | `character`           |
| `side`                | `character`           |
| `number_of_contracts` | `numeric` (flattened) |
| `current_price`       | `numeric` (flattened) |
| `avg_entry_price`     | `numeric` (flattened) |
| `unrealized_pnl`      | `numeric` (flattened) |
| `daily_realized_pnl`  | `numeric` (flattened) |
| `expiration_time`     | `POSIXct` (UTC)       |

``` r

futures$get_positions()[]
```

    #>         product_id   side number_of_contracts current_price avg_entry_price
    #>             <char> <char>               <num>         <num>           <num>
    #> 1: BIT-31OCT26-CDE  SHORT                   3      74101.53           74500
    #>    unrealized_pnl daily_realized_pnl     expiration_time
    #>             <num>              <num>              <POSc>
    #> 1:         -125.4               42.1 2026-10-31 16:00:00

#### Sweeps

Parser `parse_futures_sweeps`, one row per sweep:

| Column             | Type                  |
|--------------------|-----------------------|
| `id`               | `character`           |
| `requested_amount` | `numeric` (flattened) |
| `should_sweep_all` | `logical`             |
| `status`           | `character`           |
| `schedule_time`    | `POSIXct` (UTC)       |

``` r

futures$get_sweeps()[]
```

    #>            id requested_amount should_sweep_all  status schedule_time
    #>        <char>            <num>           <lgcl>  <char>        <POSc>
    #> 1: sweep-0001              500            FALSE PENDING    2026-05-31

#### Margin window and settings

`get_current_margin_window()` (parser `parse_margin_window`) flattens
the nested `margin_window` object into scalars — a single row with
`margin_window_type` (character), `end_time` (`POSIXct`),
`is_intraday_margin_killswitch_enabled` (logical), and
`is_intraday_margin_enrollment_killswitch_enabled` (logical). It
requires a `margin_profile_type` argument. `schedule_sweep()`,
`cancel_sweep()`, and `get_intraday_margin_setting()` go through the
generic `as_dt_row` flattener; `set_intraday_margin_setting()` returns a
single-row `data.table(setting = <applied value>)` because the success
body is empty.

``` r

futures$get_current_margin_window("MARGIN_PROFILE_TYPE_RETAIL_INTRADAY_MARGIN_1")[]
futures$get_intraday_margin_setting()[]
```

    #>                  margin_window_type            end_time
    #>                              <char>              <POSc>
    #> 1: FCM_MARGIN_WINDOW_TYPE_OVERNIGHT 2026-05-31 13:30:00
    #>    is_intraday_margin_killswitch_enabled
    #>                                   <lgcl>
    #> 1:                                 FALSE
    #>    is_intraday_margin_enrollment_killswitch_enabled
    #>                                              <lgcl>
    #> 1:                                            FALSE
    #>                             setting
    #>                              <char>
    #> 1: INTRADAY_MARGIN_SETTING_STANDARD

------------------------------------------------------------------------

### Standalone helpers

#### Credentials and base URLs

``` r

adv_url <- get_base_url()              # api.coinbase.com (auth)
ex_url  <- get_exchange_base_url()     # api.exchange.coinbase.com (public)
c(advanced_trade = adv_url, exchange = ex_url)
```

    #>                      advanced_trade                            exchange 
    #>          "https://api.coinbase.com" "https://api.exchange.coinbase.com"

[`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)
reads `COINBASE_API_KEY_NAME` / `COINBASE_API_PRIVATE_KEY` from
`.Renviron` (never run with real credentials in a document):

``` r

keys <- get_api_keys()   # reads .Renviron
```

#### Low-level HTTP

[`coinbase_build_request()`](https://dereckscompany.github.io/coinbase/reference/coinbase_build_request.md)
constructs and JWT-signs every request. You should rarely call it
directly — every method goes through it — but it is exported so you can
wrap any not-yet-bound endpoint without re-implementing ES256 / EdDSA
signing.

#### Bulk tick-history download

[`coinbase_backfill_trades()`](https://dereckscompany.github.io/coinbase/reference/coinbase_backfill_trades.md)
downloads deep tick history for many products and writes the results to
a CSV incrementally, so progress survives an interruption. It writes to
disk, so it is shown but not run here:

``` r

box::use(coinbase[coinbase_backfill_trades], lubridate[ymd])

# Backfill deep tick history for many products, with CSV resume so an
# aborted run doesn't restart from scratch.
coinbase_backfill_trades(
  symbols = c("BTC-USD", "ETH-USD"),
  from    = ymd("2024-01-01"),
  to      = ymd("2024-02-01"),
  file    = "data/trades.csv"
)
```

#### Tick aggregation: `trades_to_ohlcv()`

This is the deep-history path. Coinbase’s `/candles` endpoint is
shallow, so complete OHLCV at any timeframe is built from ticks:
download trades, then aggregate.
[`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md)
takes a `data.table` with `time` (`POSIXct`), `price` (`numeric`), and
`size` (`numeric`) columns — exactly what `get_trades()` /
`get_trades_history()` return — plus an `interval` in seconds, and
returns the canonical six-column OHLCV table:

| Column     | Type            | Notes                        |
|------------|-----------------|------------------------------|
| `datetime` | `POSIXct` (UTC) | floored bar start            |
| `open`     | `numeric`       | first trade price in the bar |
| `high`     | `numeric`       | max trade price in the bar   |
| `low`      | `numeric`       | min trade price in the bar   |
| `close`    | `numeric`       | last trade price in the bar  |
| `volume`   | `numeric`       | summed trade size            |

Open/close are the first/last trade by time (`trade_id` breaks ties
within an identical timestamp when present); empty intervals produce no
row. The column layout matches `get_ohlcv()` exactly, so candle data
from either source is interchangeable.

``` r

ticks <- market$get_trades("BTC-USD", limit = 1000L)
bars  <- trades_to_ohlcv(ticks, interval = 60)   # 1-minute bars
bars[, .(datetime, open, high, low, close, volume)]
```

    #>               datetime     open     high      low    close     volume
    #>                 <POSc>    <num>    <num>    <num>    <num>      <num>
    #> 1: 2026-05-31 04:58:00 74100.98 74101.54 74100.98 74101.53 0.01258607

#### Symbol verification and client order IDs

``` r

verify_symbol("BTC-USD")          # TRUE
verify_symbol("BIT-28FEB25-CDE")  # TRUE  (multi-segment expiring future)
verify_symbol("BTCUSD")           # FALSE (no dash separator)

generate_client_order_id()        # fresh RFC-4122 v4 UUID
```

    #> [1] TRUE
    #> [1] TRUE
    #> [1] FALSE
    #> [1] "1aa24e1e-9ab9-4e16-9a23-6c1f9a1160c0"

#### Async usage

Pass `async = TRUE` to any class constructor; methods then return
promises. Drive them with the
[`coro::async()`](https://coro.r-lib.org/reference/async.html) /
`await()` idiom and drain the `later` event loop. No pipes anywhere.

``` r

box::use(
  coro[async, await],
  later
)

market_async <- CoinbaseMarketData$new(async = TRUE)
results <- NULL

main <- async(function() {
  ticker  <- await(market_async$get_ticker("BTC-USD"))
  candles <- await(market_async$get_ohlcv("BTC-USD", granularity = "1min"))
  results <<- list(ticker = ticker, candles = candles)
  return(invisible(NULL))
})

main()
while (!later$loop_empty()) later$run_now()

results$ticker[]
results$candles[]
```

    #>         ask      bid   volume   trade_id    price    size                time
    #>       <num>    <num>    <num>      <int>    <num>   <num>              <POSc>
    #> 1: 74101.53 74101.52 3600.231 1026942323 74101.53 5.2e-07 2026-05-31 04:58:29
    #>    rfq_volume
    #>         <num>
    #> 1:    10.7929
    #>               datetime     open     high      low    close volume
    #>                 <POSc>    <num>    <num>    <num>    <num>  <num>
    #> 1: 2026-05-31 04:53:00 74055.40 74070.12 74050.00 74067.15 1.4820
    #> 2: 2026-05-31 04:54:00 74113.49 74113.49 74067.15 74068.26 3.0535
    #> 3: 2026-05-31 04:55:00 74068.26 74093.61 74068.26 74093.60 0.9691
    #> 4: 2026-05-31 04:56:00 74093.60 74099.83 74093.59 74099.83 0.1151

See
[`vignette("async-usage", package = "coinbase")`](https://dereckscompany.github.io/coinbase/articles/async-usage.md)
for the full pattern.

------------------------------------------------------------------------

## Data-shape conventions

Now that you’ve seen the surface, here are the rules used to decide what
a row in the returned `data.table` represents.

Every method follows one principle:

> **Identify the entity for the endpoint, and return one row per
> entity.**

A trade gets a row. An order gets a row. An account balance gets a row.
A candle gets a row. Anything nested *under* the entity becomes a flat
column on the same row or an additional row on a different axis —
**never a list column**.

The overriding invariant on `coinbase` is the no-list-column contract.
Even the generic flatteners (`as_dt_row` / `as_dt_list`) enforce it: any
nested object, array, or multi-element value that doesn’t have a
hand-written parser is collapsed to a single JSON string rather than
left as a list cell. There are four treatments.

### Treatment A — Flatten `{value, currency}` amounts to numerics

Coinbase represents monetary amounts as nested `{value, currency}`
objects on the wire. Every such field is flattened to its numeric
`value` (helpers `amount_value` / `flex_num`), dropping the currency tag
— the currency is already implied by the column or by a sibling
`currency` column.

``` r

accts <- account$get_accounts()
accts$available_balance     # numeric, not list({value=..., currency=...})

bal <- futures$get_balance_summary()
bal$futures_buying_power    # numeric, flattened from {value, currency}
```

    #> [1]     0.5321 12500.4200
    #> [1] 9500

Where it’s used: `available_balance` / `hold` on accounts; every amount
on the futures balance summary, positions, and sweeps
(`futures_buying_power`, `unrealized_pnl`, `current_price`,
`avg_entry_price`, `requested_amount`, …). `flex_num` is the lenient
variant — it accepts either a bare scalar or a `{value, currency}`
object — because some futures fields arrive in either form depending on
the account state.

### Treatment B — Long format for arrays of objects

When an array’s elements are themselves records (each has a `price`, a
`size`, a `side`, …), explode to one row per element with a `side` or
position column where order matters. On `coinbase` this applies to
exactly one endpoint: the order book.

``` r

ob <- market$get_orderbook("BTC-USD", level = 2L)
ob[, .(side, price, size, num_orders)]
```

    #>      side    price       size num_orders
    #>    <char>    <num>      <num>      <num>
    #> 1:    bid 74101.52 0.43541938          5
    #> 2:    bid 74101.38 0.00067474          1
    #> 3:    bid 74098.69 0.00266800          1
    #> 4:    ask 74101.53 0.08631688          7
    #> 5:    ask 74103.63 0.26058806          2
    #> 6:    ask 74103.66 0.00140588          2

The `bids` and `asks` arrays are stacked with a `side` discriminator.
The level-3 distinction is the subtle part: at levels 1-2 the third
element is an order **count** (`num_orders`, numeric); at level 3 the
book is non-aggregated and the third element is an **`order_id`**
string, so the parser emits a character `order_id` column instead. Check
which you got with `"order_id" %in% names(ob)`.

### Treatment C — Flatten fixed-schema nested objects to scalar columns

When the nested data is an *object* (not an array) with a known fixed
key set, flatten the inner fields into scalar columns on the same row.
The entity stays one row.

``` r

fees <- account$get_fees()
fees$maker_fee_rate   # was nested under fee_tier
fees$pricing_tier     # was nested under fee_tier

orders <- trading$get_orders(product_ids = "BTC-USD")
orders$config_type    # the order_configuration's one key
orders$limit_price    # was nested inside order_configuration
```

    #> [1] 0.004
    #> [1] "Advanced 1"
    #> [1] "limit_limit_gtc"   "market_market_ioc"
    #> [1] 70000    NA

Where it’s used: `fee_tier` on `get_fees` (`pricing_tier` /
`maker_fee_rate` / `taker_fee_rate` / `usd_from` / `usd_to`);
`order_configuration` on orders, create-order, and preview
(`config_type`, `base_size`, `quote_size`, `limit_price`, `stop_price`,
`stop_trigger_price`, `stop_direction`, `end_time`, `post_only` — see
`flatten_order_config`); `margin_window` on `get_current_margin_window`.
The detailed-type key of `order_configuration` is surfaced as the
`config_type` column, distinct from the coarse `order_type` enum.

### Treatment D — Collapse error arrays to one string

Coinbase returns validation / preview / edit errors as an array whose
elements are sometimes objects and sometimes bare strings, and whose
reason lives under different keys per endpoint (`error_code`,
`new_order_failure_reason`, `preview_failure_reason`,
`edit_failure_reason`, `failure_reason`, `error`, `message`, …). Rather
than leave a list column, `collapse_errors` looks each element up by its
known keys and joins the array into a single `"; "`-separated character
string — `NA_character_` when there are no errors.

``` r

pv <- trading$preview_order(
  "BTC-USD", "BUY",
  list(market_market_ioc = list(quote_size = "10"))
)
pv$errs   # one string, or NA when the preview validated cleanly
```

    #> [1] NA

Where it’s used: `errs` on `preview_order`; `failure_reason` on
`add_order` and `cancel_orders`; `errors` on `edit_order` and
`preview_edit_order`.

### The generic fallback

Methods without a hand-written parser (`get_products`, `get_product`,
`get_ticker`, `get_portfolios`, `get_key_permissions`,
`get_server_time`, `schedule_sweep`, `cancel_sweep`,
`get_intraday_margin_setting`) go through `as_dt_row` / `as_dt_list`.
These flatten every scalar field into a column and, crucially, collapse
any unexpected nested object/array or multi-element value to a single
JSON string — so even an endpoint the package doesn’t model in detail
still returns a list-column-free table. Recover such a field with
[`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
if you ever need its structure.

### Two cross-cutting rules

These apply to every treatment, regardless of method.

1.  **Empty / null field → scalar `NA` (typed), not a list cell.** A
    missing balance is `NA_real_`, a missing timestamp is `NA`
    (`POSIXct`), a missing string is `NA_character_`. Downstream
    [`is.na()`](https://rdrr.io/r/base/NA.html) keeps working; no
    list-column gymnastics.
2.  **Empty response → empty `data.table`.** No synthetic stub rows.
    `get_trades()` with nothing to return, `cancel_orders()` whose batch
    matched nothing, `get_positions()` with no open positions — all
    return a zero-row table.
    [`nrow()`](https://rdrr.io/r/base/nrow.html) is the honest count of
    “things I got back,” and the absence of an error is the success
    signal.

### What was *not* done

A few intentional non-goals, shared with the sister `alpaca`, `binance`,
and `kucoin` packages:

- **No list columns, ever.** This is the headline guarantee. Nested
  `{value, currency}` amounts are flattened to numerics, fixed-schema
  objects to scalar columns, error arrays to a single string, and any
  unmodelled nesting to a JSON string. A returned table never hides a
  list cell.
- **No automatic local-time conversion.** Timestamps come back as UTC
  `POSIXct`. Convert with `format(x, tz = "America/New_York")` or
  similar at display time.
- **`client_order_id` is round-tripped verbatim.** Whatever string you
  pass (or the UUID
  [`generate_client_order_id()`](https://dereckscompany.github.io/coinbase/reference/generate_client_order_id.md)
  mints) goes back to you unchanged.
- **No client-side rate-limiting.** The package surfaces Coinbase’s
  rate-limit errors but does not back off on its own — that is the
  caller’s job.
- **No reconnect / retry on transient network errors.** The single call
  is what you asked for; wrap with
  [`httr2::req_retry()`](https://httr2.r-lib.org/reference/req_retry.html)
  (passed through
  [`coinbase_build_request()`](https://dereckscompany.github.io/coinbase/reference/coinbase_build_request.md))
  if you want retries.

### Why this matters across exchanges

The `alpaca`, `binance`, `kucoin`, and `coinbase` packages all follow
the same shape rule. Once you’ve learned `data.table` idioms for one of
them, the same idioms work on the others — pivot a portfolio’s balances
across multiple exchanges with a straight `rbindlist` plus an `exchange`
column, no per-source shape massage and no escape hatch into `lapply`
over hidden lists.

``` r

# Combine spot accounts + futures balance into one ledger
ledger <- data.table::rbindlist(
  list(
    account$get_accounts()[, wallet := "spot"],
    futures$get_balance_summary()[, wallet := "futures"]
  ),
  use.names = TRUE,
  fill = TRUE
)
ledger[, .(wallet, currency, available_balance, futures_buying_power)]
```

    #>     wallet currency available_balance futures_buying_power
    #>     <char>   <char>             <num>                <num>
    #> 1:    spot      BTC            0.5321                   NA
    #> 2:    spot      USD        12500.4200                   NA
    #> 3: futures     <NA>                NA                 9500

The same predictability is what makes the connector layer (`exchanges`
package, on top of `tradebot-core`) easy to write: each raw wrapper
returns data the connector can re-shape without special-casing list
columns or unwrapping nested structures.

### See also

- [`vignette("getting-started", package = "coinbase")`](https://dereckscompany.github.io/coinbase/articles/getting-started.md)
  — guided walk through fetching market data, placing a preview order,
  and querying balances.
- [`vignette("async-usage", package = "coinbase")`](https://dereckscompany.github.io/coinbase/articles/async-usage.md)
  — using the same methods with `async = TRUE`.
- The sister `alpaca`, `binance`, and `kucoin` packages — the same
  convention applied to other exchanges, with the same Package Tour
  layout. \`\`\`
