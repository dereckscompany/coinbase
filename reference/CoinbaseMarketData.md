# CoinbaseMarketData: Public Market Data Retrieval

Retrieves public market data from the Coinbase Exchange API: products,
candles (OHLCV), tick trades, order books, tickers, and server time.
These are unauthenticated, with one exception: `get_best_bid_ask()` hits
the Advanced Trade host and requires credentials.

Inherits from
[CoinbaseBase](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md).
All methods support both synchronous and asynchronous execution
depending on the `async` argument at construction.

### Deep history

The `/candles` endpoint returns roughly 300 bars per request, so it is a
convenience for recent data only. Complete OHLCV at any timeframe is
built from ticks: page `get_trades()` (or call the backfill) back
through history, then aggregate with
[`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md).

### Endpoints Covered

|                    |                                    |      |
|--------------------|------------------------------------|------|
| Method             | Endpoint                           | Auth |
| get_products       | GET /products                      | No   |
| get_product        | GET /products/{id}                 | No   |
| get_ohlcv          | GET /products/{id}/candles         | No   |
| get_trades         | GET /products/{id}/trades          | No   |
| get_trades_history | GET /products/{id}/trades (paged)  | No   |
| get_orderbook      | GET /products/{id}/book            | No   |
| get_ticker         | GET /products/{id}/ticker          | No   |
| get_stats          | GET /products/stats                | No   |
| get_product_stats  | GET /products/{id}/stats           | No   |
| get_best_bid_ask   | GET /api/v3/brokerage/best_bid_ask | Yes  |
| get_server_time    | GET /time                          | No   |

## Super class

[`CoinbaseBase`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md)
-\> `CoinbaseMarketData`

## Methods

### Public methods

- [`CoinbaseMarketData$get_products()`](#method-CoinbaseMarketData-get_products)

- [`CoinbaseMarketData$get_product()`](#method-CoinbaseMarketData-get_product)

- [`CoinbaseMarketData$get_ohlcv()`](#method-CoinbaseMarketData-get_ohlcv)

- [`CoinbaseMarketData$get_trades()`](#method-CoinbaseMarketData-get_trades)

- [`CoinbaseMarketData$get_trades_history()`](#method-CoinbaseMarketData-get_trades_history)

- [`CoinbaseMarketData$get_orderbook()`](#method-CoinbaseMarketData-get_orderbook)

- [`CoinbaseMarketData$get_ticker()`](#method-CoinbaseMarketData-get_ticker)

- [`CoinbaseMarketData$get_stats()`](#method-CoinbaseMarketData-get_stats)

- [`CoinbaseMarketData$get_product_stats()`](#method-CoinbaseMarketData-get_product_stats)

- [`CoinbaseMarketData$get_best_bid_ask()`](#method-CoinbaseMarketData-get_best_bid_ask)

- [`CoinbaseMarketData$get_server_time()`](#method-CoinbaseMarketData-get_server_time)

- [`CoinbaseMarketData$clone()`](#method-CoinbaseMarketData-clone)

Inherited methods

- [`CoinbaseBase$initialize()`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.html#method-initialize)

------------------------------------------------------------------------

### `CoinbaseMarketData$get_products()`

Retrieve all available trading products (currency pairs).

#### Usage

    CoinbaseMarketData$get_products()

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of products, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_product()`

Retrieve metadata for a single product.

#### Usage

    CoinbaseMarketData$get_product(product_id)

#### Arguments

- `product_id`:

  Character; the pair symbol, e.g. `"BTC-USD"`.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_ohlcv()`

Retrieve OHLCV candles for a product. Returns roughly 300 bars per call;
for deep history aggregate ticks with
[`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md).

#### Usage

    CoinbaseMarketData$get_ohlcv(
      product_id,
      granularity = "1min",
      start = NULL,
      end = NULL
    )

#### Arguments

- `product_id`:

  Character; the pair symbol, e.g. `"BTC-USD"`.

- `granularity`:

  Character; one of `"1min"`, `"5min"`, `"15min"`, `"1hour"`, `"6hour"`,
  `"1day"`.

- `start`:

  POSIXct or NULL; range start. Optional.

- `end`:

  POSIXct or NULL; range end. Optional.

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `datetime`, `open`, `high`, `low`, `close`, `volume`, or a
promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_trades()`

Retrieve recent tick trades for a product. To page further back, pass
the smallest `trade_id` seen as `after`.

#### Usage

    CoinbaseMarketData$get_trades(product_id, limit = 1000L, after = NULL)

#### Arguments

- `product_id`:

  Character; the pair symbol, e.g. `"BTC-USD"`.

- `limit`:

  Integer; trades to return (max 1000). Default 1000.

- `after`:

  Numeric or NULL; return trades older than this `trade_id`.

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `trade_id`, `side`, `price`, `size`, `time`, or a promise
thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_trades_history()`

Retrieve deep tick history by paging the trades endpoint backwards in
time. This is the backfill path: pages from the most recent trade toward
`start` (or the product's first-ever trade if `start` is NULL), then
deduplicates and sorts ascending. Aggregate the result with
[`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md)
for deep OHLCV at any timeframe.

#### Usage

    CoinbaseMarketData$get_trades_history(
      product_id,
      start = NULL,
      end = NULL,
      max_pages = Inf
    )

#### Arguments

- `product_id`:

  Character; the pair symbol, e.g. `"BTC-USD"`.

- `start`:

  POSIXct or NULL; stop once trades older than this are reached.

- `end`:

  POSIXct or NULL; drop trades newer than this. Paging always begins at
  the most recent trade.

- `max_pages`:

  Numeric; cap on pages fetched (each up to 1000 trades). Default `Inf`.

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `trade_id`, `side`, `price`, `size`, `time` sorted
ascending by `time`, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_orderbook()`

Retrieve an order book snapshot for a product.

#### Usage

    CoinbaseMarketData$get_orderbook(product_id, level = 2L)

#### Arguments

- `product_id`:

  Character; the pair symbol, e.g. `"BTC-USD"`.

- `level`:

  Integer; `1` (best bid/ask), `2` (top 50 aggregated), or `3` (full,
  non-aggregated). Default 2.

#### Returns

A long
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `side`, `price`, `size`, and a third column that is
`num_orders` (numeric) at levels 1-2 or `order_id` (character) at level
3, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_ticker()`

Retrieve the latest ticker (best bid/ask, last trade) for a product.

#### Usage

    CoinbaseMarketData$get_ticker(product_id)

#### Arguments

- `product_id`:

  Character; the pair symbol, e.g. `"BTC-USD"`.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_stats()`

Retrieve 24-hour and 30-day stats for *every* product in a single call –
the basis for a market scanner / movers screener. Rank the returned
table yourself by 24h change `(last - open) / open` for top
gainers/losers, or by `volume` for the most active products. Uses the
Exchange host's bulk stats endpoint.

#### Usage

    CoinbaseMarketData$get_stats()

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with one row per product: `product_id`, `open`, `high`, `low`, `last`,
`volume`, `volume_30day`, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_product_stats()`

Retrieve 24-hour and 30-day stats for a single product.

#### Usage

    CoinbaseMarketData$get_product_stats(product_id)

#### Arguments

- `product_id`:

  Character; the pair symbol, e.g. `"BTC-USD"`.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `open`, `high`, `low`, `last`, `volume`, `volume_30day`, and the
RFQ/conversion volumes, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_best_bid_ask()`

Retrieve the best bid/ask for many products in one call. Unlike the
other `CoinbaseMarketData` methods, this hits the **Advanced Trade**
host and therefore **requires credentials** (construct the client with
`keys`).

#### Usage

    CoinbaseMarketData$get_best_bid_ask(product_ids = NULL)

#### Arguments

- `product_ids`:

  Character vector or NULL; products to fetch. `NULL` returns the best
  bid/ask for all products.

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with one row per product: `product_id`, `bid_price`, `bid_size`,
`ask_price`, `ask_size`, `time`, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$get_server_time()`

Retrieve the Coinbase Exchange server time.

#### Usage

    CoinbaseMarketData$get_server_time()

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `iso` and `epoch`, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseMarketData$clone()`

The objects of this class are cloneable with this method.

#### Usage

    CoinbaseMarketData$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
market <- CoinbaseMarketData$new()
market$get_ticker("BTC-USD")
market$get_ohlcv("BTC-USD", granularity = "1min")

# Asynchronous
market_async <- CoinbaseMarketData$new(async = TRUE)
main <- coro::async(function() {
  ticker <- await(market_async$get_ticker("BTC-USD"))
  print(ticker)
})
main()
while (!later::loop_empty()) later::run_now()
} # }
```
