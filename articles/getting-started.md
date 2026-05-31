# Getting Started with coinbase

This vignette demonstrates how to use `coinbase` in **synchronous** mode
to retrieve public market data, read authenticated account state, and
safely *preview* orders against the Coinbase Advanced Trade API.

## Disclaimer

This software is provided for educational and research purposes. Trading
cryptocurrency carries substantial risk and you are solely responsible
for any orders placed through this package. Every example that could
move money is shown as a `preview_order()` dry run (which executes
nothing); the one live `add_order()` call is left commented out.
Validate with a preview before submitting anything live.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("dereckscompany/coinbase")
```

## Setup

Public market data needs no credentials. Authenticated endpoints
(accounts, fees, trading) require a Coinbase Developer Platform (CDP)
API key. Create one at <https://www.coinbase.com/settings/api> and
download the JSON file, which contains a `name` and a `privateKey`.

Store the credentials as environment variables in `.Renviron`. The
downloaded `privateKey` is multi-line PEM; to keep it on a single line,
escape its newlines as the two characters `\n`
([`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)
unescapes them back before use). Both EC keys
(`-----BEGIN EC PRIVATE KEY-----`, signed with ES256) and base64-encoded
Ed25519 keys (signed with EdDSA) are supported.

``` bash
COINBASE_API_KEY_NAME="organizations/<org-uuid>/apiKeys/<key-uuid>"
COINBASE_API_PRIVATE_KEY="-----BEGIN EC PRIVATE KEY-----\n<fake-key-body>\n-----END EC PRIVATE KEY-----\n"
```

> **Two hosts.** Coinbase splits across two hosts. Authenticated trading
> and account endpoints use the Advanced Trade host
> (`https://api.coinbase.com`,
> [`get_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_base_url.md));
> the public market-data endpoints with deep history use the Exchange
> host (`https://api.exchange.coinbase.com`,
> [`get_exchange_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_exchange_base_url.md)).
> Each class selects the correct host per request, so you rarely set
> these by hand.

``` r

box::use(
  coinbase[
    CoinbaseMarketData, CoinbaseAccount, CoinbaseTrading,
    trades_to_ohlcv, coinbase_backfill_trades, get_api_keys
  ]
)

keys <- get_api_keys(
  api_key_name = "organizations/<org-uuid>/apiKeys/<key-uuid>",
  api_private_key = "-----BEGIN EC PRIVATE KEY-----\n<fake-key-body>\n-----END EC PRIVATE KEY-----\n"
)
```

When the environment variables are set,
[`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)
reads them with no arguments, so in practice you simply call
`CoinbaseAccount$new()` and the credentials are picked up automatically.

------------------------------------------------------------------------

## Market Data

The `CoinbaseMarketData` class covers all public (no auth) market
endpoints. It talks to the Exchange host, which exposes deep trade
history.

``` r

market <- CoinbaseMarketData$new()
```

### Products

List every available trading product (currency pair):

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

### Ticker

Best bid/ask and the last trade for a single product:

``` r

ticker <- market$get_ticker(product_id = "BTC-USD")
ticker[]
```

    #>         ask      bid   volume   trade_id    price    size                time
    #>       <num>    <num>    <num>      <int>    <num>   <num>              <POSc>
    #> 1: 74101.53 74101.52 3600.231 1026942323 74101.53 5.2e-07 2026-05-31 04:58:29
    #>    rfq_volume
    #>         <num>
    #> 1:    10.7929

### OHLCV Candles

The `/candles` endpoint returns roughly 300 bars per call, so it is a
convenience for recent data. Valid granularities are `"1min"`, `"5min"`,
`"15min"`, `"1hour"`, `"6hour"`, and `"1day"`. The result has columns
`datetime`, `open`, `high`, `low`, `close`, `volume`:

``` r

candles <- market$get_ohlcv(product_id = "BTC-USD", granularity = "1min")
candles[]
```

    #>               datetime     open     high      low    close volume
    #>                 <POSc>    <num>    <num>    <num>    <num>  <num>
    #> 1: 2026-05-31 04:53:00 74055.40 74070.12 74050.00 74067.15 1.4820
    #> 2: 2026-05-31 04:54:00 74113.49 74113.49 74067.15 74068.26 3.0535
    #> 3: 2026-05-31 04:55:00 74068.26 74093.61 74068.26 74093.60 0.9691
    #> 4: 2026-05-31 04:56:00 74093.60 74099.83 74093.59 74099.83 0.1151

### Recent Trades

Recent tick trades, with columns `trade_id`, `side`, `price`, `size`,
`time`:

``` r

trades <- market$get_trades(product_id = "BTC-USD", limit = 100)
trades[]
```

    #>      trade_id   side    price       size                time
    #>         <num> <char>    <num>      <num>              <POSc>
    #> 1: 1026942323   sell 74101.53 0.00000052 2026-05-31 04:58:29
    #> 2: 1026942322   sell 74101.53 0.00000240 2026-05-31 04:58:29
    #> 3: 1026942321    buy 74101.54 0.00058315 2026-05-31 04:58:29
    #> 4: 1026942320    buy 74100.98 0.01200000 2026-05-31 04:58:28

### Order Book

A snapshot at level `1` (best bid/ask), `2` (top 50 aggregated), or `3`
(full, non-aggregated). The result is a long table with a `side` column:

``` r

book <- market$get_orderbook(product_id = "BTC-USD", level = 2)
book[]
```

    #>      side    price       size num_orders
    #>    <char>    <num>      <num>      <num>
    #> 1:    bid 74101.52 0.43541938          5
    #> 2:    bid 74101.38 0.00067474          1
    #> 3:    bid 74098.69 0.00266800          1
    #> 4:    ask 74101.53 0.08631688          7
    #> 5:    ask 74103.63 0.26058806          2
    #> 6:    ask 74103.66 0.00140588          2

### Server Time

``` r

st <- market$get_server_time()
st[]
```

    #>                         iso      epoch
    #>                      <char>      <num>
    #> 1: 2026-05-31T04:58:31.547Z 1780203512

### Market Stats (Scanner Source)

`get_stats()` returns 24-hour and 30-day stats for **every** product in
a single call – the basis for a market scanner. Rank the returned table
yourself, e.g. by `volume` for the most active products or by 24h change
`(last - open) / open` for the top movers:

``` r

stats <- market$get_stats()

# Most active products by 24h volume
head(stats[order(-volume)], 5)

# Biggest 24h gainers
stats[, change := (last - open) / open]
head(stats[order(-change)], 5)
```

    #>    product_id     open     high   low     last    volume volume_30day
    #>        <char>    <num>    <num> <num>    <num>     <num>        <num>
    #> 1:    SOL-USD   150.00   162.00   148   159.80 900000.00   28000000.0
    #> 2:    ETH-USD  2400.10  2455.00  2390  2440.55  55000.00    1500000.0
    #> 3:    BTC-USD 73504.38 74156.59 73382 73958.00   3477.63     177000.5
    #>    product_id     open     high   low     last    volume volume_30day
    #>        <char>    <num>    <num> <num>    <num>     <num>        <num>
    #> 1:    SOL-USD   150.00   162.00   148   159.80 900000.00   28000000.0
    #> 2:    ETH-USD  2400.10  2455.00  2390  2440.55  55000.00    1500000.0
    #> 3:    BTC-USD 73504.38 74156.59 73382 73958.00   3477.63     177000.5
    #>         change
    #>          <num>
    #> 1: 0.065333333
    #> 2: 0.016853464
    #> 3: 0.006171333

For a single product, `get_product_stats()` also carries the
RFQ/conversion volumes:

``` r

market$get_product_stats("BTC-USD")[]
```

    #>        open     high   low  last  volume volume_30day rfq_volume_24hour
    #>       <num>    <num> <num> <num>   <num>        <num>             <num>
    #> 1: 73504.38 74156.59 73382 73958 3477.63     177000.5          10.52636
    #>    rfq_volume_30day conversions_volume_24hour conversions_volume_30day
    #>               <num>                     <num>                    <num>
    #> 1:          1393.92                         0                        0

### Best Bid/Ask Across Products

`get_best_bid_ask()` returns the top of book for many products in one
call. Unlike the other `CoinbaseMarketData` methods it uses the Advanced
Trade host, so it **requires credentials**:

``` r

market_auth <- CoinbaseMarketData$new()
```

``` r

market_auth$get_best_bid_ask(c("BTC-USD", "ETH-USD"))[]
```

    #>    product_id bid_price   bid_size ask_price   ask_size                time
    #>        <char>     <num>      <num>     <num>      <num>              <POSc>
    #> 1:    BTC-USD  74101.52  0.4354194  74101.53 0.08631688 2026-05-31 04:58:29
    #> 2:    ETH-USD   2440.50 12.0000000   2440.60 8.50000000 2026-05-31 04:58:29

------------------------------------------------------------------------

## Deep Tick History and OHLCV

Coinbase’s candle endpoint is shallow, so complete OHLCV at any
timeframe is built from ticks. `get_trades_history()` pages the trades
endpoint backwards from the most recent trade toward `start`,
deduplicates, and returns the trades sorted ascending by `time`:

``` r

ticks <- market$get_trades_history(
  product_id = "BTC-USD",
  start = lubridate::as_datetime("2026-05-31 00:00:00", tz = "UTC"),
  end = lubridate::as_datetime("2026-05-31 06:00:00", tz = "UTC")
)
ticks[]
```

    #>      trade_id   side    price       size                time
    #>         <num> <char>    <num>      <num>              <POSc>
    #> 1: 1026942320    buy 74100.98 0.01200000 2026-05-31 04:58:28
    #> 2: 1026942321    buy 74101.54 0.00058315 2026-05-31 04:58:29
    #> 3: 1026942322   sell 74101.53 0.00000240 2026-05-31 04:58:29
    #> 4: 1026942323   sell 74101.53 0.00000052 2026-05-31 04:58:29

> **Note:** Tick volume is large. Bound the window with `start`/`end`,
> and use `max_pages` to cap how far back paging walks (each page is up
> to 1000 trades).

Aggregate those ticks into OHLCV bars at any interval (in seconds) with
[`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md).
The result mirrors `get_ohlcv()`: `datetime`, `open`, `high`, `low`,
`close`, `volume`:

``` r

bars <- trades_to_ohlcv(ticks, interval = 60)
bars[]
```

    #>               datetime     open     high      low    close     volume
    #>                 <POSc>    <num>    <num>    <num>    <num>      <num>
    #> 1: 2026-05-31 04:58:00 74100.98 74101.54 74100.98 74101.53 0.01258607

------------------------------------------------------------------------

## Bulk Backfill (Data Collection)

[`coinbase_backfill_trades()`](https://dereckscompany.github.io/coinbase/reference/coinbase_backfill_trades.md)
is the data-collection workflow: it downloads deep tick history for one
or more products and writes the results to a CSV incrementally, so
progress survives an interruption. Re-running the same call resumes each
product from its last recorded trade.

It writes a file to disk, so it is shown here but not executed:

``` r

coinbase_backfill_trades(
  symbols = c("BTC-USD", "ETH-USD"),
  from = lubridate::as_datetime("2026-05-01", tz = "UTC"),
  to = lubridate::as_datetime("2026-05-30", tz = "UTC"),
  file = "trades.csv"
)

# Resume an interrupted backfill -- just run the same call again. It reads the
# existing CSV and continues each symbol from its last stored trade.
```

The function returns the file path invisibly. If any symbols failed, a
`"failures"` attribute is attached: a `data.table` with `symbol` and
`error` columns. Once the CSV is collected, read it back and aggregate
to OHLCV with
[`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md).

------------------------------------------------------------------------

## Account Information

The `CoinbaseAccount` class reads authenticated account state from the
Advanced Trade host. All endpoints require credentials.

``` r

account <- CoinbaseAccount$new()
```

### Balances

`get_accounts()` walks Coinbase’s cursor pagination to return every
account. Balances arrive as numeric columns (`available_balance`,
`hold`), never nested objects:

``` r

accounts <- account$get_accounts()
accounts[, .(uuid, currency, available_balance, hold, type)]
```

    #>                                    uuid currency available_balance  hold
    #>                                  <char>   <char>             <num> <num>
    #> 1: 8bfc20d7-f7c6-4422-bf07-8243ca4169fe      BTC            0.5321     0
    #> 2: 1a2b3c4d-5e6f-4789-90ab-cdef01234567      USD        12500.4200   250
    #>                   type
    #>                 <char>
    #> 1: ACCOUNT_TYPE_CRYPTO
    #> 2:   ACCOUNT_TYPE_FIAT

### Fee Tier

`get_fees()` returns the transaction summary, including the current
maker/taker fee tier:

``` r

fees <- account$get_fees()
fees[, .(pricing_tier, maker_fee_rate, taker_fee_rate, total_volume)]
```

    #>    pricing_tier maker_fee_rate taker_fee_rate total_volume
    #>          <char>          <num>          <num>        <num>
    #> 1:   Advanced 1          0.004          0.006     125000.5

### Key Permissions

Confirm what the calling API key is allowed to do:

``` r

perms <- account$get_key_permissions()
perms[]
```

    #>    can_view can_trade can_transfer                       portfolio_uuid
    #>      <lgcl>    <lgcl>       <lgcl>                               <char>
    #> 1:     TRUE      TRUE        FALSE 9c2f8b1e-1111-4d3a-9aaa-0123456789ab
    #>    portfolio_type
    #>            <char>
    #> 1:        DEFAULT

### Portfolios

`get_portfolios()` lists your portfolios; `get_portfolio_breakdown()`
returns the per-asset breakdown of one. The positions come back as the
`data.table` (one row per holding, tagged with `position_type`), while
the portfolio’s aggregate balance totals are attached as a one-row
`data.table` in the `"summary"` attribute:

``` r

ports <- account$get_portfolios()
ports[]
```

    #>       name                                 uuid     type
    #>     <char>                               <char>   <char>
    #> 1: Default 9c2f8b1e-1111-4d3a-9aaa-0123456789ab  DEFAULT
    #> 2:    Algo 7d6e5f4c-2222-4b1a-8ccc-fedcba987654 CONSUMER

``` r

bd <- account$get_portfolio_breakdown(ports$uuid[1])
bd[, .(position_type, asset, total_balance_fiat, allocation, cost_basis)]

# Portfolio-level totals live on the "summary" attribute
attr(bd, "summary")[]
```

    #>    position_type           asset total_balance_fiat allocation cost_basis
    #>           <char>          <char>              <num>      <num>      <num>
    #> 1:          spot             BTC              60000       0.48      55000
    #> 2:          spot             USD              40000       0.32      40000
    #> 3:       futures BIT-28FEB25-CDE              25000       0.20         NA
    #>                                    uuid   name     type total_balance
    #>                                  <char> <char>   <char>         <num>
    #> 1: 7d6e5f4c-2222-4b1a-8ccc-fedcba987654   Algo CONSUMER        125000
    #>    total_futures_balance total_cash_equivalent_balance total_crypto_balance
    #>                    <num>                         <num>                <num>
    #> 1:                 25000                         40000                85000
    #>    total_neptune_balance
    #>                    <num>
    #> 1:                     0

------------------------------------------------------------------------

## Trading

The `CoinbaseTrading` class places, previews, edits, cancels, and
queries orders and fills. All endpoints require credentials.

``` r

trading <- CoinbaseTrading$new()
```

### Order Configuration

Orders carry an `order_configuration`: a one-key named list whose key
names the detailed order type. Common shapes:

``` r

# Market buy of $10 (quote-denominated)
market_cfg <- list(market_market_ioc = list(quote_size = "10"))

# Limit buy of 0.001 BTC at 50000, good-till-cancelled
limit_cfg <- list(
  limit_limit_gtc = list(base_size = "0.001", limit_price = "50000")
)
```

### Preview an Order (Safe Dry Run)

`preview_order()` validates an order **without placing it** — it
executes nothing. It returns the estimated `order_total`,
`commission_total`, sizes, `best_bid`/`best_ask`, `slippage`, any
validation `errs`, and a `preview_id`. Always preview before submitting
a live order:

``` r

preview <- trading$preview_order(
  product_id = "BTC-USD",
  side = "BUY",
  order_configuration = market_cfg
)
preview[, .(order_total, commission_total, base_size, best_ask, errs)]
```

    #>    order_total commission_total base_size best_ask   errs
    #>          <num>            <num>     <num>    <num> <char>
    #> 1:       10.06             0.06  0.000135 74101.53   <NA>

`preview_order()` also accepts the optional `leverage`, `margin_type`
(`"CROSS"` or `"ISOLATED"`), and `retail_portfolio_id` arguments.

### Place an Order

`add_order()` submits a live order that may execute. It mirrors
`preview_order()` and additionally accepts `client_order_id` (an
idempotency key, defaulting to a fresh UUID) and
`self_trade_prevention_id`. The call below runs against the mock;
against the live API it would place a real order, so preview first:

``` r

order <- trading$add_order(
  product_id = "BTC-USD",
  side = "BUY",
  order_configuration = limit_cfg
)
order[, .(success, order_id, product_id, side)]
```

    #>    success                             order_id product_id   side
    #>     <lgcl>                               <char>     <char> <char>
    #> 1:    TRUE 1111aaaa-2222-bbbb-3333-cccccccccccc    BTC-USD    BUY

### Edit an Order

`preview_edit_order()` is a dry run for an edit (it changes nothing),
and `edit_order()` applies a new price and/or size to an open order:

``` r

edit_preview <- trading$preview_edit_order(
  order_id = order$order_id,
  price = "71000"
)
edit_preview[, .(order_total, commission_total, slippage)]

edited <- trading$edit_order(order_id = order$order_id, price = "71000")
edited[, .(success, order_id)]
```

    #>    order_total commission_total slippage
    #>          <num>            <num>    <num>
    #> 1:       70.07             0.07    2e-04
    #>    success                             order_id
    #>     <lgcl>                               <char>
    #> 1:    TRUE 1111aaaa-2222-bbbb-3333-cccccccccccc

### Query Orders

`get_orders()` retrieves historical orders, paginating over the cursor.
It accepts a rich set of filters, including `product_ids`,
`order_status`, `order_side`, `order_ids`, `start_date`/`end_date`,
`order_types`, `product_type`, `time_in_forces`, and `sort_by`:

``` r

orders <- trading$get_orders(
  product_ids = "BTC-USD",
  order_status = "OPEN",
  limit = 10,
  sort_by = "LAST_FILL_TIME"
)
orders[, .(order_id, product_id, side, status, order_type, filled_size)]
```

    #>                                order_id product_id   side status order_type
    #>                                  <char>     <char> <char> <char>     <char>
    #> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc    BTC-USD    BUY   OPEN      LIMIT
    #> 2: 4444dddd-5555-eeee-6666-ffffffffffff    ETH-USD   SELL FILLED     MARKET
    #>    filled_size
    #>          <num>
    #> 1:         0.0
    #> 2:         0.5

### Query Fills

`get_fills()` retrieves historical fills. Filter by `order_ids`
(plural), `trade_ids`, `product_ids`, the `start_sequence_timestamp` /
`end_sequence_timestamp` bounds, and `sort_by`:

``` r

fills <- trading$get_fills(
  product_ids = "BTC-USD",
  sort_by = "TRADE_TIME"
)
fills[, .(trade_id, order_id, side, price, size, commission)]
```

    #>      trade_id                             order_id   side  price  size
    #>        <char>                               <char> <char>  <num> <num>
    #> 1: trade-0001 4444dddd-5555-eeee-6666-ffffffffffff   SELL 3850.2   0.3
    #> 2: trade-0002 4444dddd-5555-eeee-6666-ffffffffffff   SELL 3850.2   0.2
    #>    commission
    #>         <num>
    #> 1:       4.62
    #> 2:       3.08

### Cancel Orders

`cancel_orders()` cancels one or more open orders by id and returns
per-order results:

``` r

cancelled <- trading$cancel_orders(order_ids = c(order$order_id))
cancelled[, .(order_id, success, failure_reason)]
```

    #>                                order_id success                failure_reason
    #>                                  <char>  <lgcl>                        <char>
    #> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc    TRUE UNKNOWN_CANCEL_FAILURE_REASON

------------------------------------------------------------------------

## Asynchronous Use

Every class works in async mode too. Pass `async = TRUE` and each method
returns a \[promise\]\[promises::promise\] instead of a `data.table`.
The recommended idiom is
[`coro::async()`](https://coro.r-lib.org/reference/async.html) /
`await()` for sequential-looking code, driving the event loop with
[later](https://r-lib.github.io/later/):

``` r

market_async <- CoinbaseMarketData$new(async = TRUE)

main <- coro$async(function() {
  ticker <- await(market_async$get_ticker(product_id = "BTC-USD"))
  candles <- await(market_async$get_ohlcv(product_id = "BTC-USD", granularity = "1min"))

  print(ticker)
  print(candles)
  return(invisible(NULL))
})

main()

# Drain the event loop until every promise has resolved.
while (!later$loop_empty()) {
  later$run_now()
}
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

------------------------------------------------------------------------

## Next Steps

- See
  [`vignette("async-usage")`](https://dereckscompany.github.io/coinbase/articles/async-usage.md)
  for promise-based asynchronous operation.
- See
  [`vignette("futures-shorting")`](https://dereckscompany.github.io/coinbase/articles/futures-shorting.md)
  for US futures (CFM) balances, positions, and the short leg via
  `CoinbaseFutures`.
- Browse the [pkgdown site](https://dereckscompany.github.io/coinbase/)
  for full method documentation.
- For bulk historical data collection, see
  [`?coinbase_backfill_trades`](https://dereckscompany.github.io/coinbase/reference/coinbase_backfill_trades.md).
