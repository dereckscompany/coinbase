# CoinbaseMarketData: Public Market Data Retrieval

CoinbaseMarketData: Public Market Data Retrieval

CoinbaseMarketData: Public Market Data Retrieval

## Details

Retrieves public market data from Coinbase: products, candles (OHLCV),
tick trades, order books, tickers, and server time. These are
unauthenticated. The product catalogue (`get_products()` /
`get_product()`) is served by the Advanced Trade public market host (it
carries the per-product order-size limits the Exchange payload omits);
the rest use the Exchange host. One method needs credentials:
`get_best_bid_ask()`.

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

|                    |                                            |      |
|--------------------|--------------------------------------------|------|
| Method             | Endpoint                                   | Auth |
| get_products       | GET /api/v3/brokerage/market/products      | No   |
| get_product        | GET /api/v3/brokerage/market/products/{id} | No   |
| get_ohlcv          | GET /products/{id}/candles                 | No   |
| get_trades         | GET /products/{id}/trades                  | No   |
| get_trades_history | GET /products/{id}/trades (paged)          | No   |
| get_orderbook      | GET /products/{id}/book                    | No   |
| get_ticker         | GET /products/{id}/ticker                  | No   |
| get_stats          | GET /products/stats                        | No   |
| get_product_stats  | GET /products/{id}/stats                   | No   |
| get_best_bid_ask   | GET /api/v3/brokerage/best_bid_ask         | Yes  |
| get_server_time    | GET /time                                  | No   |

## Super classes

[`connectcore::RestClient`](https://rdrr.io/pkg/connectcore/man/RestClient.html)
-\>
[`coinbase::CoinbaseBase`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md)
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

- [`coinbase::CoinbaseBase$initialize()`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.html#method-initialize)

------------------------------------------------------------------------

### Method `get_products()`

Retrieve all available trading products (currency pairs), including each
product's order-size limits (`base_min_size` / `base_max_size` /
`quote_min_size` / `quote_max_size`) and increments. Sourced from the
Advanced Trade public market host, which — unlike the Exchange
`/products` payload — carries those size limits.

#### Usage

    CoinbaseMarketData$get_products()

#### Returns

(Products \| promise\<Products\>) one row per tradable product, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_product()`

Retrieve metadata for a single product, including its order-size limits
and increments. The single-row form of the `get_products()` shape, from
the same Advanced Trade public market host.

#### Usage

    CoinbaseMarketData$get_product(product_id)

#### Arguments

- `product_id`:

  (scalar\<character\>) the pair symbol, e.g. `"BTC-USD"`.

#### Returns

(Products \| promise\<Products\>) a single-row table of product
metadata, or a promise thereof.

------------------------------------------------------------------------

### Method `get_ohlcv()`

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

  (scalar\<character\>) the pair symbol, e.g. `"BTC-USD"`.

- `granularity`:

  (scalar\<character in c("1min", "5min", "15min", "1hour", "6hour",
  "1day")\>) the candle interval.

- `start`:

  (POSIXct \| NULL) range start. Optional.

- `end`:

  (POSIXct \| NULL) range end. Optional.

#### Returns

(Ohlcv \| promise\<Ohlcv\>) one row per candle ascending by `datetime`,
or a promise thereof.

------------------------------------------------------------------------

### Method `get_trades()`

Retrieve recent tick trades for a product. To page further back, pass
the smallest `trade_id` seen as `after`.

#### Usage

    CoinbaseMarketData$get_trades(product_id, limit = 1000L, after = NULL)

#### Arguments

- `product_id`:

  (scalar\<character\>) the pair symbol, e.g. `"BTC-USD"`.

- `limit`:

  (scalar\<count in \[1, Inf\[\>) trades to return (max 1000). Default
  1000.

- `after`:

  (scalar\<numeric\> \| NULL) return trades older than this `trade_id`.

#### Returns

(Trades \| promise\<Trades\>) one row per tick trade, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_trades_history()`

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

  (scalar\<character\>) the pair symbol, e.g. `"BTC-USD"`.

- `start`:

  (POSIXct \| NULL) stop once trades older than this are reached.

- `end`:

  (POSIXct \| NULL) drop trades newer than this. Paging always begins at
  the most recent trade.

- `max_pages`:

  (scalar\<numeric in \[1, Inf\]\>) cap on pages fetched (each up to
  1000 trades). Default `Inf`.

#### Returns

(Trades \| promise\<Trades\>) one row per tick trade sorted ascending by
`time`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_orderbook()`

Retrieve an order book snapshot for a product.

#### Usage

    CoinbaseMarketData$get_orderbook(product_id, level = 2L)

#### Arguments

- `product_id`:

  (scalar\<character\>) the pair symbol, e.g. `"BTC-USD"`.

- `level`:

  (scalar\<count in \[1, 3\]\>) `1` (best bid/ask), `2` (top 50
  aggregated), or `3` (full, non-aggregated). Default 2.

#### Returns

(data.table \| promise\<data.table\>) a long table with columns `side`,
`price`, `size`, and a third column that is `num_orders` (numeric) at
levels 1-2 or `order_id` (character) at level 3, or a promise thereof.

------------------------------------------------------------------------

### Method `get_ticker()`

Retrieve the latest ticker (best bid/ask, last trade) for a product.

#### Usage

    CoinbaseMarketData$get_ticker(product_id)

#### Arguments

- `product_id`:

  (scalar\<character\>) the pair symbol, e.g. `"BTC-USD"`.

#### Returns

(data.table \| promise\<data.table\>) a single-row table (the `trade_id`
and any `rfq_volume` columns are passed through untyped), or a promise
thereof.

- price (numeric \| NA) last trade price.

- size (numeric \| NA) last trade size in the base asset.

- timestamp (POSIXct) last trade time (UTC).

- bid (numeric \| NA) best bid price.

- ask (numeric \| NA) best ask price.

- volume (numeric \| NA) 24-hour volume.

------------------------------------------------------------------------

### Method `get_stats()`

Retrieve 24-hour and 30-day stats for *every* product in a single call –
the basis for a market scanner / movers screener. Rank the returned
table yourself by 24h change `(last - open) / open` for top
gainers/losers, or by `volume` for the most active products. Uses the
Exchange host's bulk stats endpoint.

#### Usage

    CoinbaseMarketData$get_stats()

#### Returns

(Stats \| promise\<Stats\>) one row per product, or a promise thereof.

------------------------------------------------------------------------

### Method `get_product_stats()`

Retrieve 24-hour and 30-day stats for a single product.

#### Usage

    CoinbaseMarketData$get_product_stats(product_id)

#### Arguments

- `product_id`:

  (scalar\<character\>) the pair symbol, e.g. `"BTC-USD"`.

#### Returns

(ProductStats \| promise\<ProductStats\>) a single-row table, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_best_bid_ask()`

Retrieve the best bid/ask for many products in one call. Unlike the
other `CoinbaseMarketData` methods, this endpoint **requires
credentials** (construct the client with `keys`); it hits the
authenticated Advanced Trade `best_bid_ask` route.

#### Usage

    CoinbaseMarketData$get_best_bid_ask(product_ids = NULL)

#### Arguments

- `product_ids`:

  (character \| NULL) products to fetch. `NULL` returns the best bid/ask
  for all products.

#### Returns

(BestBidAsk \| promise\<BestBidAsk\>) one row per product, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_server_time()`

Retrieve the Coinbase Exchange server time.

#### Usage

    CoinbaseMarketData$get_server_time()

#### Returns

(data.table \| promise\<data.table\>) a single-row table, or a promise
thereof.

- iso (character) the server time as an ISO-8601 string.

- epoch (numeric) the server time as Unix epoch seconds.

------------------------------------------------------------------------

### Method `clone()`

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
