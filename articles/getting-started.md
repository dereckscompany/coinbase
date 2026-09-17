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

    #>         product_id product_type base_currency_id quote_currency_id base_name
    #>             <char>       <char>           <char>            <char>    <char>
    #> 1:         BTC-USD         SPOT              BTC               USD   Bitcoin
    #> 2:         ETH-USD         SPOT              ETH               USD  Ethereum
    #> 3:         SOL-USD         SPOT              SOL               USD    Solana
    #> 4:        USDC-EUR         SPOT             USDC               EUR  USD Coin
    #> 5:     OLDCOIN-USD         SPOT          OLDCOIN               USD  Old Coin
    #> 6: BIT-31OCT26-CDE       FUTURE              BIT               USD   Bitcoin
    #>    quote_name  display_name base_increment quote_increment price_increment
    #>        <char>        <char>         <char>          <char>          <char>
    #> 1:  US Dollar       BTC-USD     0.00000001            0.01            0.01
    #> 2:  US Dollar       ETH-USD     0.00000001            0.01            0.01
    #> 3:  US Dollar       SOL-USD          0.001            0.01            0.01
    #> 4:       Euro      USDC-EUR           0.01          0.0001          0.0001
    #> 5:  US Dollar   OLDCOIN-USD           0.01          0.0001          0.0001
    #> 6:  US Dollar BTC 31 OCT 26              1               1               1
    #>    base_min_size base_max_size quote_min_size quote_max_size   status
    #>           <char>        <char>         <char>         <char>   <char>
    #> 1:    0.00000001          3400              1      150000000   online
    #> 2:    0.00000001         27000              1       50000000   online
    #> 3:         0.001         66000              1       10000000   online
    #> 4:          0.01      22000000           0.84       20000000   online
    #> 5:          0.01     100000000              1        1000000 delisted
    #> 6:             1        100000              1       10000000   online
    #>    trading_disabled is_disabled    new cancel_only limit_only post_only
    #>              <lgcl>      <lgcl> <lgcl>      <lgcl>     <lgcl>    <lgcl>
    #> 1:            FALSE       FALSE  FALSE       FALSE      FALSE     FALSE
    #> 2:            FALSE       FALSE  FALSE       FALSE      FALSE     FALSE
    #> 3:            FALSE       FALSE  FALSE       FALSE      FALSE     FALSE
    #> 4:            FALSE       FALSE  FALSE       FALSE       TRUE     FALSE
    #> 5:             TRUE        TRUE  FALSE        TRUE      FALSE     FALSE
    #> 6:            FALSE       FALSE  FALSE       FALSE      FALSE     FALSE
    #>    auction_mode view_only
    #>          <lgcl>    <lgcl>
    #> 1:        FALSE     FALSE
    #> 2:        FALSE     FALSE
    #> 3:        FALSE     FALSE
    #> 4:        FALSE     FALSE
    #> 5:        FALSE      TRUE
    #> 6:        FALSE     FALSE

### Ticker

Best bid/ask and the last trade for a single product:

``` r

ticker <- market$get_ticker(product_id = "BTC-USD")
ticker[]
```

    #>         ask   bid volume trade_id    price  size rfq_volume           timestamp
    #>       <num> <num>  <num>    <int>    <num> <num>      <num>              <POSc>
    #> 1: 50000.05 50000 1200.5  1000101 50000.02  0.01       12.5 2026-01-05 09:30:00

### OHLCV Candles

The `/candles` endpoint returns roughly 300 bars per call, so it is a
convenience for recent data. Valid granularities are `"1min"`, `"5min"`,
`"15min"`, `"1hour"`, `"6hour"`, and `"1day"`. The result has columns
`datetime`, `open`, `high`, `low`, `close`, `volume`:

``` r

candles <- market$get_ohlcv(product_id = "BTC-USD", granularity = "1min")
candles[]
```

    #>                datetime  open  high   low close volume
    #>                  <POSc> <num> <num> <num> <num>  <num>
    #>  1: 2026-01-05 00:00:00 50000 50015 49990 50005     10
    #>  2: 2026-01-05 01:00:00 50005 50015 49990 50000     11
    #>  3: 2026-01-05 02:00:00 50000 50015 49990 50005     12
    #>  4: 2026-01-05 03:00:00 50005 50015 49990 50000     13
    #>  5: 2026-01-05 04:00:00 50000 50015 49990 50005     14
    #>  6: 2026-01-05 05:00:00 50005 50015 49990 50000     10
    #>  7: 2026-01-05 06:00:00 50000 50015 49990 50005     11
    #>  8: 2026-01-05 07:00:00 50005 50015 49990 50000     12
    #>  9: 2026-01-05 08:00:00 50000 50015 49990 50005     13
    #> 10: 2026-01-05 09:00:00 50005 50015 49990 50000     14
    #> 11: 2026-01-05 10:00:00 50000 50015 49990 50005     10
    #> 12: 2026-01-05 11:00:00 50005 50015 49990 50000     11
    #> 13: 2026-01-05 12:00:00 50000 50015 49990 50005     12
    #> 14: 2026-01-05 13:00:00 50005 50015 49990 50000     13
    #> 15: 2026-01-05 14:00:00 50000 50015 49990 50005     14
    #> 16: 2026-01-05 15:00:00 50005 50015 49990 50000     10
    #> 17: 2026-01-05 16:00:00 50000 50015 49990 50005     11
    #> 18: 2026-01-05 17:00:00 50005 50015 49990 50000     12
    #> 19: 2026-01-05 18:00:00 50000 50015 49990 50005     13
    #> 20: 2026-01-05 19:00:00 50005 50015 49990 50000     14
    #> 21: 2026-01-05 20:00:00 50000 50015 49990 50005     10
    #> 22: 2026-01-05 21:00:00 50005 50015 49990 50000     11
    #> 23: 2026-01-05 22:00:00 50000 50015 49990 50005     12
    #> 24: 2026-01-05 23:00:00 50005 50015 49990 50000     13
    #>                datetime  open  high   low close volume
    #>                  <POSc> <num> <num> <num> <num>  <num>

### Recent Trades

Recent tick trades, with columns `trade_id`, `side`, `price`, `size`,
`timestamp`:

``` r

trades <- market$get_trades(product_id = "BTC-USD", limit = 100)
trades[]
```

    #>     trade_id   side   price  size           timestamp
    #>        <num> <char>   <num> <num>              <POSc>
    #>  1:  1000030    buy 50000.0  0.01 2026-01-05 09:30:00
    #>  2:  1000029   sell 50000.5  0.02 2026-01-05 09:29:55
    #>  3:  1000028    buy 50001.0  0.03 2026-01-05 09:29:50
    #>  4:  1000027   sell 50001.5  0.04 2026-01-05 09:29:45
    #>  5:  1000026    buy 50002.0  0.01 2026-01-05 09:29:40
    #>  6:  1000025   sell 50002.5  0.02 2026-01-05 09:29:35
    #>  7:  1000024    buy 50000.0  0.03 2026-01-05 09:29:30
    #>  8:  1000023   sell 50000.5  0.04 2026-01-05 09:29:25
    #>  9:  1000022    buy 50001.0  0.01 2026-01-05 09:29:20
    #> 10:  1000021   sell 50001.5  0.02 2026-01-05 09:29:15
    #> 11:  1000020    buy 50002.0  0.03 2026-01-05 09:29:10
    #> 12:  1000019   sell 50002.5  0.04 2026-01-05 09:29:05
    #> 13:  1000018    buy 50000.0  0.01 2026-01-05 09:29:00
    #> 14:  1000017   sell 50000.5  0.02 2026-01-05 09:28:55
    #> 15:  1000016    buy 50001.0  0.03 2026-01-05 09:28:50
    #> 16:  1000015   sell 50001.5  0.04 2026-01-05 09:28:45
    #> 17:  1000014    buy 50002.0  0.01 2026-01-05 09:28:40
    #> 18:  1000013   sell 50002.5  0.02 2026-01-05 09:28:35
    #> 19:  1000012    buy 50000.0  0.03 2026-01-05 09:28:30
    #> 20:  1000011   sell 50000.5  0.04 2026-01-05 09:28:25
    #> 21:  1000010    buy 50001.0  0.01 2026-01-05 09:28:20
    #> 22:  1000009   sell 50001.5  0.02 2026-01-05 09:28:15
    #> 23:  1000008    buy 50002.0  0.03 2026-01-05 09:28:10
    #> 24:  1000007   sell 50002.5  0.04 2026-01-05 09:28:05
    #> 25:  1000006    buy 50000.0  0.01 2026-01-05 09:28:00
    #> 26:  1000005   sell 50000.5  0.02 2026-01-05 09:27:55
    #> 27:  1000004    buy 50001.0  0.03 2026-01-05 09:27:50
    #> 28:  1000003   sell 50001.5  0.04 2026-01-05 09:27:45
    #> 29:  1000002    buy 50002.0  0.01 2026-01-05 09:27:40
    #> 30:  1000001   sell 50002.5  0.02 2026-01-05 09:27:35
    #>     trade_id   side   price  size           timestamp
    #>        <num> <char>   <num> <num>              <POSc>

### Order Book

A snapshot at level `1` (best bid/ask), `2` (top 50 aggregated), or `3`
(full, non-aggregated). The result is a long table with a `side` column:

``` r

book <- market$get_orderbook(product_id = "BTC-USD", level = 2)
book[]
```

    #>       side    price  size num_orders
    #>     <char>    <num> <num>      <num>
    #>  1:    bid 50000.00  0.10          1
    #>  2:    bid 49999.00  0.11          2
    #>  3:    bid 49998.00  0.12          3
    #>  4:    bid 49997.00  0.13          4
    #>  5:    bid 49996.00  0.14          5
    #>  6:    bid 49995.00  0.15          6
    #>  7:    bid 49994.00  0.16          7
    #>  8:    bid 49993.00  0.17          8
    #>  9:    bid 49992.00  0.18          9
    #> 10:    bid 49991.00  0.19         10
    #> 11:    ask 50000.05  0.10          1
    #> 12:    ask 50001.05  0.11          2
    #> 13:    ask 50002.05  0.12          3
    #> 14:    ask 50003.05  0.13          4
    #> 15:    ask 50004.05  0.14          5
    #> 16:    ask 50005.05  0.15          6
    #> 17:    ask 50006.05  0.16          7
    #> 18:    ask 50007.05  0.17          8
    #> 19:    ask 50008.05  0.18          9
    #> 20:    ask 50009.05  0.19         10
    #>       side    price  size num_orders
    #>     <char>    <num> <num>      <num>

### Server Time

``` r

st <- market$get_server_time()
st[]
```

    #>                     iso      epoch
    #>                  <char>      <num>
    #> 1: 2026-01-05T09:30:00Z 1767605400

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

    #>    product_id  open  high   low    last   volume volume_30day
    #>        <char> <num> <num> <num>   <num>    <num>        <num>
    #> 1:    SOL-USD   145   155   140   150.5 42000.00    900000.00
    #> 2:    ETH-USD  2950  3050  2900  3005.0  6200.25    180000.50
    #> 3:    BTC-USD 49500 50800 49300 50250.0  1200.50     36000.75
    #>    product_id  open  high   low    last   volume volume_30day     change
    #>        <char> <num> <num> <num>   <num>    <num>        <num>      <num>
    #> 1:    SOL-USD   145   155   140   150.5 42000.00    900000.00 0.03793103
    #> 2:    ETH-USD  2950  3050  2900  3005.0  6200.25    180000.50 0.01864407
    #> 3:    BTC-USD 49500 50800 49300 50250.0  1200.50     36000.75 0.01515152

For a single product, `get_product_stats()` also carries the
RFQ/conversion volumes:

``` r

market$get_product_stats("BTC-USD")[]
```

    #>     open  high   low  last volume volume_30day rfq_volume_24hour
    #>    <num> <num> <num> <num>  <num>        <num>             <num>
    #> 1: 49500 50800 49300 50250 1200.5     36000.75              12.5
    #>    rfq_volume_30day conversions_volume_24hour conversions_volume_30day
    #>               <num>                     <num>                    <num>
    #> 1:           375.25                        NA                       NA

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

    #>    product_id bid_price bid_size ask_price ask_size           timestamp
    #>        <char>     <num>    <num>     <num>    <num>              <POSc>
    #> 1:    BTC-USD     50000      0.5  50000.05      0.4 2026-01-05 09:30:00

------------------------------------------------------------------------

## Deep Tick History and OHLCV

Coinbase’s candle endpoint is shallow, so complete OHLCV at any
timeframe is built from ticks. `get_trades_history()` pages the trades
endpoint backwards from the most recent trade toward `start`,
deduplicates, and returns the trades sorted ascending by `timestamp`:

``` r

ticks <- market$get_trades_history(
  product_id = "BTC-USD",
  start = lubridate::as_datetime("2026-05-31 00:00:00", tz = "UTC"),
  end = lubridate::as_datetime("2026-05-31 06:00:00", tz = "UTC")
)
ticks[]
```

    #> Empty data.table (0 rows and 5 cols): trade_id,side,price,size,timestamp

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

    #> Empty data.table (0 rows and 6 cols): datetime,open,high,low,close,volume

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
    #> 1: 00000000-0000-4000-8000-000000000001      BTC             5e-01   0.0
    #> 2: 00000000-0000-4000-8000-000000000003      ETH             2e+00   0.0
    #> 3: 00000000-0000-4000-8000-000000000004      SOL             1e+01   0.5
    #> 4: 00000000-0000-4000-8000-000000000005      USD             1e+03   0.0
    #> 5: 00000000-0000-4000-8000-000000000006     USDC             5e+02   0.0
    #> 6: 00000000-0000-4000-8000-000000000007     DOGE             0e+00   0.0
    #>                   type
    #>                 <char>
    #> 1: ACCOUNT_TYPE_CRYPTO
    #> 2: ACCOUNT_TYPE_CRYPTO
    #> 3: ACCOUNT_TYPE_CRYPTO
    #> 4:   ACCOUNT_TYPE_FIAT
    #> 5: ACCOUNT_TYPE_CRYPTO
    #> 6: ACCOUNT_TYPE_CRYPTO

### Fee Tier

`get_fees()` returns the transaction summary, including the current
maker/taker fee tier:

``` r

fees <- account$get_fees()
fees[, .(pricing_tier, maker_fee_rate, taker_fee_rate, total_volume)]
```

    #>    pricing_tier maker_fee_rate taker_fee_rate total_volume
    #>          <char>          <num>          <num>        <num>
    #> 1:      Intro 1          0.006          0.012            0

### Key Permissions

Confirm what the calling API key is allowed to do:

``` r

perms <- account$get_key_permissions()
perms[]
```

    #>    can_view can_trade can_transfer                       portfolio_uuid
    #>      <lgcl>    <lgcl>       <lgcl>                               <char>
    #> 1:     TRUE      TRUE        FALSE 00000000-0000-4000-8000-000000000002
    #>    portfolio_type
    #>            <char>
    #> 1:        DEFAULT

### Portfolios

`get_portfolios()` lists your portfolios. For one portfolio,
`get_portfolio_breakdown()` returns its positions (spot, futures, and
perpetual) stacked into one `data.table`, tagged with `position_type`,
and `get_portfolio_summary()` returns the portfolio’s aggregate totals
as a separate one-row `data.table` (both read the same endpoint):

``` r

ports <- account$get_portfolios()
ports[]
```

    #>       name                                 uuid    type deleted
    #>     <char>                               <char>  <char>  <lgcl>
    #> 1: Default 00000000-0000-4000-8000-000000000002 DEFAULT   FALSE

``` r

bd <- account$get_portfolio_breakdown(ports$uuid[1])
bd[, .(position_type, product_id, asset, side, entry_price, mark_price, unrealized_pnl)]

# Portfolio-level totals come from a separate one-row table
account$get_portfolio_summary(ports$uuid[1])[]
```

    #>    position_type      product_id  asset   side entry_price mark_price
    #>           <char>          <char> <char> <char>       <num>      <num>
    #> 1:          spot            <NA>    BTC   <NA>       67900         NA
    #> 2:          spot            <NA>    USD   <NA>          NA         NA
    #> 3:       futures BIT-28FEB26-CDE   <NA>   LONG       95000      96000
    #> 4:          perp   BTC-PERP-INTX   <NA>   LONG       94000      95500
    #>    unrealized_pnl
    #>             <num>
    #> 1:           5000
    #> 2:              0
    #> 3:            120
    #> 4:             45
    #>                                    uuid   name     type total_balance
    #>                                  <char> <char>   <char>         <num>
    #> 1: 7d6e5f4c-2222-4b1a-8ccc-fedcba987654   Algo CONSUMER        125000
    #>    total_futures_balance total_cash_equivalent_balance total_crypto_balance
    #>                    <num>                         <num>                <num>
    #> 1:                 25000                         40000                85000
    #>    futures_unrealized_pnl perp_unrealized_pnl total_equities_balance
    #>                     <num>               <num>                  <num>
    #> 1:                    120                  45                      0

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

    #>                                order_id product_id   side    status order_type
    #>                                  <char>     <char> <char>    <char>     <char>
    #> 1: 00000000-0000-4000-8000-000000000028    ETH-USD    BUY CANCELLED      LIMIT
    #> 2: 00000000-0000-4000-8000-000000000030    ETH-USD    BUY CANCELLED      LIMIT
    #> 3: 00000000-0000-4000-8000-000000000032    SOL-USD    BUY CANCELLED      LIMIT
    #>    filled_size
    #>          <num>
    #> 1:           0
    #> 2:           0
    #> 3:           0

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

    #>         ask   bid volume trade_id    price  size rfq_volume           timestamp
    #>       <num> <num>  <num>    <int>    <num> <num>      <num>              <POSc>
    #> 1: 50000.05 50000 1200.5  1000101 50000.02  0.01       12.5 2026-01-05 09:30:00
    #>                datetime  open  high   low close volume
    #>                  <POSc> <num> <num> <num> <num>  <num>
    #>  1: 2026-01-05 00:00:00 50000 50015 49990 50005     10
    #>  2: 2026-01-05 01:00:00 50005 50015 49990 50000     11
    #>  3: 2026-01-05 02:00:00 50000 50015 49990 50005     12
    #>  4: 2026-01-05 03:00:00 50005 50015 49990 50000     13
    #>  5: 2026-01-05 04:00:00 50000 50015 49990 50005     14
    #>  6: 2026-01-05 05:00:00 50005 50015 49990 50000     10
    #>  7: 2026-01-05 06:00:00 50000 50015 49990 50005     11
    #>  8: 2026-01-05 07:00:00 50005 50015 49990 50000     12
    #>  9: 2026-01-05 08:00:00 50000 50015 49990 50005     13
    #> 10: 2026-01-05 09:00:00 50005 50015 49990 50000     14
    #> 11: 2026-01-05 10:00:00 50000 50015 49990 50005     10
    #> 12: 2026-01-05 11:00:00 50005 50015 49990 50000     11
    #> 13: 2026-01-05 12:00:00 50000 50015 49990 50005     12
    #> 14: 2026-01-05 13:00:00 50005 50015 49990 50000     13
    #> 15: 2026-01-05 14:00:00 50000 50015 49990 50005     14
    #> 16: 2026-01-05 15:00:00 50005 50015 49990 50000     10
    #> 17: 2026-01-05 16:00:00 50000 50015 49990 50005     11
    #> 18: 2026-01-05 17:00:00 50005 50015 49990 50000     12
    #> 19: 2026-01-05 18:00:00 50000 50015 49990 50005     13
    #> 20: 2026-01-05 19:00:00 50005 50015 49990 50000     14
    #> 21: 2026-01-05 20:00:00 50000 50015 49990 50005     10
    #> 22: 2026-01-05 21:00:00 50005 50015 49990 50000     11
    #> 23: 2026-01-05 22:00:00 50000 50015 49990 50005     12
    #> 24: 2026-01-05 23:00:00 50005 50015 49990 50000     13
    #>                datetime  open  high   low close volume
    #>                  <POSc> <num> <num> <num> <num>  <num>

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
