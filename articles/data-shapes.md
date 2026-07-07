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
| `get_products()` | `GET /api/v3/brokerage/market/products` | one row per product |
| `get_product(product_id)` | `GET /api/v3/brokerage/market/products/{id}` | single row |
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

`get_products()` and `get_product()` source the product catalogue from
the Advanced Trade public market host
(`/api/v3/brokerage/market/products`), which — unlike the Exchange
`/products` payload — carries each product’s order-size limits
(`base_min_size` / `base_max_size` / `quote_min_size` /
`quote_max_size`) and increments (`base_increment` / `quote_increment` /
`price_increment`). The parser (`parse_products`) selects a curated,
typed set of columns (one row per product); `get_product()` is the
single-row form of the same shape. Numeric-looking fields are returned
as the character strings Coinbase sends — cast at the point of use.

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

A single product is the same row shape:

``` r

market$get_product("BTC-USD")[]
```

    #>    product_id product_type base_currency_id quote_currency_id base_name
    #>        <char>       <char>           <char>            <char>    <char>
    #> 1:    BTC-USD         SPOT              BTC               USD   Bitcoin
    #>    quote_name display_name base_increment quote_increment price_increment
    #>        <char>       <char>         <char>          <char>          <char>
    #> 1:  US Dollar      BTC-USD     0.00000001            0.01            0.01
    #>    base_min_size base_max_size quote_min_size quote_max_size status
    #>           <char>        <char>         <char>         <char> <char>
    #> 1:    0.00000001          3400              1      150000000 online
    #>    trading_disabled is_disabled    new cancel_only limit_only post_only
    #>              <lgcl>      <lgcl> <lgcl>      <lgcl>     <lgcl>    <lgcl>
    #> 1:            FALSE       FALSE  FALSE       FALSE      FALSE     FALSE
    #>    auction_mode view_only
    #>          <lgcl>    <lgcl>
    #> 1:        FALSE     FALSE

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

    #>                 datetime     open     high      low    close    volume
    #>                   <POSc>    <num>    <num>    <num>    <num>     <num>
    #>   1: 2026-06-27 11:53:00 60239.24 60259.03 60237.18 60254.55 0.5974811
    #>   2: 2026-06-27 11:54:00 60254.55 60259.22 60245.28 60253.71 1.3447478
    #>   3: 2026-06-27 11:55:00 60253.71 60277.48 60253.35 60261.37 1.9928412
    #>   4: 2026-06-27 11:56:00 60261.37 60271.22 60261.37 60267.93 0.5881228
    #>   5: 2026-06-27 11:57:00 60267.94 60275.14 60267.93 60275.14 1.4672205
    #>  ---                                                                  
    #> 346: 2026-06-27 17:38:00 60488.71 60542.10 60486.43 60531.97 0.8154508
    #> 347: 2026-06-27 17:39:00 60531.98 60557.40 60490.84 60498.00 3.7195266
    #> 348: 2026-06-27 17:40:00 60499.25 60510.05 60490.08 60506.00 0.6947636
    #> 349: 2026-06-27 17:41:00 60506.00 60509.35 60494.01 60500.51 0.9226553
    #> 350: 2026-06-27 17:42:00 60500.51 60510.05 60500.51 60510.04 0.0020467

`granularity` is one of `"1min"`, `"5min"`, `"15min"`, `"1hour"`,
`"6hour"`, `"1day"`.

#### Trades

`get_trades()` and `get_trades_history()` (parser `parse_trades`) return
one row per tick trade, with exactly five typed columns:

| Column      | Type            | Notes      |
|-------------|-----------------|------------|
| `trade_id`  | `numeric`       |            |
| `side`      | `character`     |            |
| `price`     | `numeric`       |            |
| `size`      | `numeric`       |            |
| `timestamp` | `POSIXct` (UTC) | trade time |

``` r

trades <- market$get_trades("BTC-USD", limit = 1000L)
trades[]
```

    #>        trade_id   side    price       size           timestamp
    #>           <num> <char>    <num>      <num>              <POSc>
    #>   1: 1045278643    buy 60488.38 0.00856426 2026-06-27 17:45:13
    #>   2: 1045278642    buy 60488.38 0.02143574 2026-06-27 17:45:13
    #>   3: 1045278641    buy 60488.40 0.00576070 2026-06-27 17:45:13
    #>   4: 1045278640    buy 60488.40 0.00888583 2026-06-27 17:45:13
    #>   5: 1045278639    buy 60488.40 0.00888601 2026-06-27 17:45:13
    #>   6: 1045278638    buy 60488.40 0.00058961 2026-06-27 17:45:13
    #>   7: 1045278637    buy 60488.40 0.03000000 2026-06-27 17:45:13
    #>   8: 1045278636    buy 60488.40 0.00028771 2026-06-27 17:45:13
    #>   9: 1045278635   sell 60487.02 0.00001900 2026-06-27 17:45:12
    #>  10: 1045278634   sell 60484.45 0.00980494 2026-06-27 17:45:12
    #>  11: 1045278633   sell 60484.44 0.02650802 2026-06-27 17:45:12
    #>  12: 1045278632   sell 60484.44 0.01280134 2026-06-27 17:45:12
    #>  13: 1045278631   sell 60484.44 0.14964316 2026-06-27 17:45:12
    #>  14: 1045278630   sell 60484.44 0.02194518 2026-06-27 17:45:12
    #>  15: 1045278629   sell 60484.44 0.02959940 2026-06-27 17:45:12
    #>  16: 1045278628   sell 60484.43 0.01564455 2026-06-27 17:45:12
    #>  17: 1045278627    buy 60483.95 0.00000005 2026-06-27 17:45:12
    #>  18: 1045278626   sell 60483.96 0.00068672 2026-06-27 17:45:12
    #>  19: 1045278625   sell 60483.96 0.00001900 2026-06-27 17:45:12
    #>  20: 1045278624    buy 60483.95 0.00000006 2026-06-27 17:45:12
    #>  21: 1045278623    buy 60483.95 0.00000007 2026-06-27 17:45:11
    #>  22: 1045278622   sell 60475.98 0.00082677 2026-06-27 17:45:11
    #>  23: 1045278621   sell 60475.88 0.00248032 2026-06-27 17:45:11
    #>  24: 1045278620    buy 60475.87 0.00000016 2026-06-27 17:45:11
    #>  25: 1045278619    buy 60475.87 0.00000043 2026-06-27 17:45:10
    #>  26: 1045278618   sell 60478.00 0.00446795 2026-06-27 17:45:10
    #>  27: 1045278617   sell 60476.07 0.00082678 2026-06-27 17:45:10
    #>  28: 1045278616   sell 60476.00 0.00560000 2026-06-27 17:45:10
    #>  29: 1045278615   sell 60475.37 0.00248034 2026-06-27 17:45:10
    #>  30: 1045278614   sell 60475.37 0.00298868 2026-06-27 17:45:10
    #>  31: 1045278613    buy 60475.36 0.00000003 2026-06-27 17:45:10
    #>  32: 1045278612    buy 60475.36 0.00000006 2026-06-27 17:45:09
    #>  33: 1045278611    buy 60475.36 0.00000006 2026-06-27 17:45:09
    #>  34: 1045278610   sell 60475.37 0.00570965 2026-06-27 17:45:08
    #>  35: 1045278609   sell 60475.37 0.00232489 2026-06-27 17:45:08
    #>  36: 1045278608    buy 60475.36 0.00000011 2026-06-27 17:45:08
    #>  37: 1045278607    buy 60475.36 0.00000004 2026-06-27 17:45:08
    #>  38: 1045278606    buy 60475.36 0.00000019 2026-06-27 17:45:07
    #>  39: 1045278605    buy 60475.36 0.00000037 2026-06-27 17:45:07
    #>  40: 1045278604    buy 60475.36 0.00000004 2026-06-27 17:45:06
    #>  41: 1045278603    buy 60475.36 0.00000019 2026-06-27 17:45:05
    #>  42: 1045278602   sell 60475.37 0.00015545 2026-06-27 17:45:05
    #>  43: 1045278601    buy 60475.36 0.00000018 2026-06-27 17:45:05
    #>  44: 1045278600    buy 60475.36 0.00691324 2026-06-27 17:45:04
    #>  45: 1045278599    buy 60475.36 0.00000024 2026-06-27 17:45:04
    #>  46: 1045278598    buy 60475.36 0.00000006 2026-06-27 17:45:04
    #>  47: 1045278597   sell 60475.37 0.00157425 2026-06-27 17:45:04
    #>  48: 1045278596   sell 60475.37 0.00171634 2026-06-27 17:45:04
    #>  49: 1045278595   sell 60475.37 0.00080334 2026-06-27 17:45:03
    #>  50: 1045278594    buy 60475.36 0.00138159 2026-06-27 17:45:03
    #>  51: 1045278593    buy 60475.36 0.00001413 2026-06-27 17:45:03
    #>  52: 1045278592    buy 60475.36 0.00000005 2026-06-27 17:45:03
    #>  53: 1045278591    buy 60475.36 0.00000006 2026-06-27 17:45:02
    #>  54: 1045278590   sell 60475.37 0.00094070 2026-06-27 17:45:02
    #>  55: 1045278589    buy 60475.36 0.00000014 2026-06-27 17:45:01
    #>  56: 1045278588   sell 60475.37 0.00068000 2026-06-27 17:45:01
    #>  57: 1045278587    buy 60475.37 0.00254302 2026-06-27 17:45:01
    #>  58: 1045278586    buy 60477.84 0.00035980 2026-06-27 17:45:01
    #>  59: 1045278585    buy 60477.84 0.00001885 2026-06-27 17:45:01
    #>  60: 1045278584   sell 60477.85 0.00435294 2026-06-27 17:45:01
    #>  61: 1045278583    buy 60477.84 0.00000015 2026-06-27 17:45:01
    #>  62: 1045278582    buy 60480.00 0.00076067 2026-06-27 17:45:00
    #>  63: 1045278581    buy 60480.90 0.00001900 2026-06-27 17:45:00
    #>  64: 1045278580    buy 60483.96 0.00001900 2026-06-27 17:45:00
    #>  65: 1045278579    buy 60487.02 0.00001900 2026-06-27 17:45:00
    #>  66: 1045278578    buy 60490.08 0.00001862 2026-06-27 17:45:00
    #>  67: 1045278577    buy 60493.14 0.00001900 2026-06-27 17:45:00
    #>  68: 1045278576    buy 60493.15 0.00770661 2026-06-27 17:45:00
    #>  69: 1045278575    buy 60493.16 0.00009918 2026-06-27 17:45:00
    #>  70: 1045278574    buy 60496.20 0.00007008 2026-06-27 17:45:00
    #>  71: 1045278573    buy 60496.20 0.00001889 2026-06-27 17:45:00
    #>  72: 1045278572    buy 60499.26 0.00001317 2026-06-27 17:45:00
    #>  73: 1045278571    buy 60499.26 0.00001236 2026-06-27 17:45:00
    #>  74: 1045278570    buy 60499.26 0.00018764 2026-06-27 17:45:00
    #>  75: 1045278569    buy 60499.26 0.00000723 2026-06-27 17:45:00
    #>  76: 1045278568    buy 60499.26 0.00003303 2026-06-27 17:45:00
    #>  77: 1045278567    buy 60499.26 0.00001784 2026-06-27 17:45:00
    #>  78: 1045278566    buy 60499.26 0.00000006 2026-06-27 17:44:59
    #>  79: 1045278565    buy 60499.26 0.00000009 2026-06-27 17:44:59
    #>  80: 1045278564   sell 60499.27 0.00862134 2026-06-27 17:44:59
    #>  81: 1045278563    buy 60499.26 0.00000013 2026-06-27 17:44:58
    #>  82: 1045278562    buy 60499.26 0.00000011 2026-06-27 17:44:58
    #>  83: 1045278561    buy 60499.26 0.00000012 2026-06-27 17:44:57
    #>  84: 1045278560    buy 60499.26 0.00000020 2026-06-27 17:44:57
    #>  85: 1045278559    buy 60499.26 0.00000003 2026-06-27 17:44:56
    #>  86: 1045278558    buy 60499.26 0.00000042 2026-06-27 17:44:55
    #>  87: 1045278557    buy 60502.32 0.00001900 2026-06-27 17:44:55
    #>  88: 1045278556    buy 60502.77 0.00116532 2026-06-27 17:44:55
    #>  89: 1045278555    buy 60502.77 0.00020098 2026-06-27 17:44:55
    #>  90: 1045278554    buy 60502.78 0.00369139 2026-06-27 17:44:55
    #>  91: 1045278553    buy 60502.78 0.03953848 2026-06-27 17:44:55
    #>  92: 1045278552    buy 60502.78 0.04293421 2026-06-27 17:44:55
    #>  93: 1045278551    buy 60502.78 0.02047379 2026-06-27 17:44:55
    #>  94: 1045278550    buy 60502.78 0.00062552 2026-06-27 17:44:55
    #>  95: 1045278549    buy 60502.78 0.02513157 2026-06-27 17:44:55
    #>  96: 1045278548    buy 60502.78 0.00213807 2026-06-27 17:44:55
    #>  97: 1045278547    buy 60502.78 0.00318947 2026-06-27 17:44:55
    #>  98: 1045278546    buy 60502.78 0.00002820 2026-06-27 17:44:55
    #>  99: 1045278545    buy 60502.78 0.00184746 2026-06-27 17:44:55
    #> 100: 1045278544    buy 60502.78 0.01564371 2026-06-27 17:44:55
    #>        trade_id   side    price       size           timestamp
    #>           <num> <char>    <num>      <num>              <POSc>

To page deeper into history with `get_trades()`, pass the smallest
`trade_id` seen so far as `after`; `get_trades_history()` does this loop
for you and returns a single de-duplicated, ascending table:

``` r

ticks <- market$get_trades_history("BTC-USD")
ticks[]
```

    #>        trade_id   side    price       size           timestamp
    #>           <num> <char>    <num>      <num>              <POSc>
    #>   1: 1045278544    buy 60502.78 0.01564371 2026-06-27 17:44:55
    #>   2: 1045278545    buy 60502.78 0.00184746 2026-06-27 17:44:55
    #>   3: 1045278546    buy 60502.78 0.00002820 2026-06-27 17:44:55
    #>   4: 1045278547    buy 60502.78 0.00318947 2026-06-27 17:44:55
    #>   5: 1045278548    buy 60502.78 0.00213807 2026-06-27 17:44:55
    #>   6: 1045278549    buy 60502.78 0.02513157 2026-06-27 17:44:55
    #>   7: 1045278550    buy 60502.78 0.00062552 2026-06-27 17:44:55
    #>   8: 1045278551    buy 60502.78 0.02047379 2026-06-27 17:44:55
    #>   9: 1045278552    buy 60502.78 0.04293421 2026-06-27 17:44:55
    #>  10: 1045278553    buy 60502.78 0.03953848 2026-06-27 17:44:55
    #>  11: 1045278554    buy 60502.78 0.00369139 2026-06-27 17:44:55
    #>  12: 1045278555    buy 60502.77 0.00020098 2026-06-27 17:44:55
    #>  13: 1045278556    buy 60502.77 0.00116532 2026-06-27 17:44:55
    #>  14: 1045278557    buy 60502.32 0.00001900 2026-06-27 17:44:55
    #>  15: 1045278558    buy 60499.26 0.00000042 2026-06-27 17:44:55
    #>  16: 1045278559    buy 60499.26 0.00000003 2026-06-27 17:44:56
    #>  17: 1045278560    buy 60499.26 0.00000020 2026-06-27 17:44:57
    #>  18: 1045278561    buy 60499.26 0.00000012 2026-06-27 17:44:57
    #>  19: 1045278562    buy 60499.26 0.00000011 2026-06-27 17:44:58
    #>  20: 1045278563    buy 60499.26 0.00000013 2026-06-27 17:44:58
    #>  21: 1045278564   sell 60499.27 0.00862134 2026-06-27 17:44:59
    #>  22: 1045278565    buy 60499.26 0.00000009 2026-06-27 17:44:59
    #>  23: 1045278566    buy 60499.26 0.00000006 2026-06-27 17:44:59
    #>  24: 1045278567    buy 60499.26 0.00001784 2026-06-27 17:45:00
    #>  25: 1045278568    buy 60499.26 0.00003303 2026-06-27 17:45:00
    #>  26: 1045278569    buy 60499.26 0.00000723 2026-06-27 17:45:00
    #>  27: 1045278570    buy 60499.26 0.00018764 2026-06-27 17:45:00
    #>  28: 1045278571    buy 60499.26 0.00001236 2026-06-27 17:45:00
    #>  29: 1045278572    buy 60499.26 0.00001317 2026-06-27 17:45:00
    #>  30: 1045278573    buy 60496.20 0.00001889 2026-06-27 17:45:00
    #>  31: 1045278574    buy 60496.20 0.00007008 2026-06-27 17:45:00
    #>  32: 1045278575    buy 60493.16 0.00009918 2026-06-27 17:45:00
    #>  33: 1045278576    buy 60493.15 0.00770661 2026-06-27 17:45:00
    #>  34: 1045278577    buy 60493.14 0.00001900 2026-06-27 17:45:00
    #>  35: 1045278578    buy 60490.08 0.00001862 2026-06-27 17:45:00
    #>  36: 1045278579    buy 60487.02 0.00001900 2026-06-27 17:45:00
    #>  37: 1045278580    buy 60483.96 0.00001900 2026-06-27 17:45:00
    #>  38: 1045278581    buy 60480.90 0.00001900 2026-06-27 17:45:00
    #>  39: 1045278582    buy 60480.00 0.00076067 2026-06-27 17:45:00
    #>  40: 1045278583    buy 60477.84 0.00000015 2026-06-27 17:45:01
    #>  41: 1045278584   sell 60477.85 0.00435294 2026-06-27 17:45:01
    #>  42: 1045278585    buy 60477.84 0.00001885 2026-06-27 17:45:01
    #>  43: 1045278586    buy 60477.84 0.00035980 2026-06-27 17:45:01
    #>  44: 1045278587    buy 60475.37 0.00254302 2026-06-27 17:45:01
    #>  45: 1045278588   sell 60475.37 0.00068000 2026-06-27 17:45:01
    #>  46: 1045278589    buy 60475.36 0.00000014 2026-06-27 17:45:01
    #>  47: 1045278590   sell 60475.37 0.00094070 2026-06-27 17:45:02
    #>  48: 1045278591    buy 60475.36 0.00000006 2026-06-27 17:45:02
    #>  49: 1045278592    buy 60475.36 0.00000005 2026-06-27 17:45:03
    #>  50: 1045278593    buy 60475.36 0.00001413 2026-06-27 17:45:03
    #>  51: 1045278594    buy 60475.36 0.00138159 2026-06-27 17:45:03
    #>  52: 1045278595   sell 60475.37 0.00080334 2026-06-27 17:45:03
    #>  53: 1045278596   sell 60475.37 0.00171634 2026-06-27 17:45:04
    #>  54: 1045278597   sell 60475.37 0.00157425 2026-06-27 17:45:04
    #>  55: 1045278598    buy 60475.36 0.00000006 2026-06-27 17:45:04
    #>  56: 1045278599    buy 60475.36 0.00000024 2026-06-27 17:45:04
    #>  57: 1045278600    buy 60475.36 0.00691324 2026-06-27 17:45:04
    #>  58: 1045278601    buy 60475.36 0.00000018 2026-06-27 17:45:05
    #>  59: 1045278602   sell 60475.37 0.00015545 2026-06-27 17:45:05
    #>  60: 1045278603    buy 60475.36 0.00000019 2026-06-27 17:45:05
    #>  61: 1045278604    buy 60475.36 0.00000004 2026-06-27 17:45:06
    #>  62: 1045278605    buy 60475.36 0.00000037 2026-06-27 17:45:07
    #>  63: 1045278606    buy 60475.36 0.00000019 2026-06-27 17:45:07
    #>  64: 1045278607    buy 60475.36 0.00000004 2026-06-27 17:45:08
    #>  65: 1045278608    buy 60475.36 0.00000011 2026-06-27 17:45:08
    #>  66: 1045278609   sell 60475.37 0.00232489 2026-06-27 17:45:08
    #>  67: 1045278610   sell 60475.37 0.00570965 2026-06-27 17:45:08
    #>  68: 1045278611    buy 60475.36 0.00000006 2026-06-27 17:45:09
    #>  69: 1045278612    buy 60475.36 0.00000006 2026-06-27 17:45:09
    #>  70: 1045278613    buy 60475.36 0.00000003 2026-06-27 17:45:10
    #>  71: 1045278614   sell 60475.37 0.00298868 2026-06-27 17:45:10
    #>  72: 1045278615   sell 60475.37 0.00248034 2026-06-27 17:45:10
    #>  73: 1045278616   sell 60476.00 0.00560000 2026-06-27 17:45:10
    #>  74: 1045278617   sell 60476.07 0.00082678 2026-06-27 17:45:10
    #>  75: 1045278618   sell 60478.00 0.00446795 2026-06-27 17:45:10
    #>  76: 1045278619    buy 60475.87 0.00000043 2026-06-27 17:45:10
    #>  77: 1045278620    buy 60475.87 0.00000016 2026-06-27 17:45:11
    #>  78: 1045278621   sell 60475.88 0.00248032 2026-06-27 17:45:11
    #>  79: 1045278622   sell 60475.98 0.00082677 2026-06-27 17:45:11
    #>  80: 1045278623    buy 60483.95 0.00000007 2026-06-27 17:45:11
    #>  81: 1045278624    buy 60483.95 0.00000006 2026-06-27 17:45:12
    #>  82: 1045278625   sell 60483.96 0.00001900 2026-06-27 17:45:12
    #>  83: 1045278626   sell 60483.96 0.00068672 2026-06-27 17:45:12
    #>  84: 1045278627    buy 60483.95 0.00000005 2026-06-27 17:45:12
    #>  85: 1045278628   sell 60484.43 0.01564455 2026-06-27 17:45:12
    #>  86: 1045278629   sell 60484.44 0.02959940 2026-06-27 17:45:12
    #>  87: 1045278630   sell 60484.44 0.02194518 2026-06-27 17:45:12
    #>  88: 1045278631   sell 60484.44 0.14964316 2026-06-27 17:45:12
    #>  89: 1045278632   sell 60484.44 0.01280134 2026-06-27 17:45:12
    #>  90: 1045278633   sell 60484.44 0.02650802 2026-06-27 17:45:12
    #>  91: 1045278634   sell 60484.45 0.00980494 2026-06-27 17:45:12
    #>  92: 1045278635   sell 60487.02 0.00001900 2026-06-27 17:45:12
    #>  93: 1045278636    buy 60488.40 0.00028771 2026-06-27 17:45:13
    #>  94: 1045278637    buy 60488.40 0.03000000 2026-06-27 17:45:13
    #>  95: 1045278638    buy 60488.40 0.00058961 2026-06-27 17:45:13
    #>  96: 1045278639    buy 60488.40 0.00888601 2026-06-27 17:45:13
    #>  97: 1045278640    buy 60488.40 0.00888583 2026-06-27 17:45:13
    #>  98: 1045278641    buy 60488.40 0.00576070 2026-06-27 17:45:13
    #>  99: 1045278642    buy 60488.38 0.02143574 2026-06-27 17:45:13
    #> 100: 1045278643    buy 60488.38 0.00856426 2026-06-27 17:45:13
    #>        trade_id   side    price       size           timestamp
    #>           <num> <char>    <num>      <num>              <POSc>

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
    #> 1:    ask 60493.74 0.09926542          1
    #> 2:    ask 60493.28 0.00019400          1
    #> 3:    ask 60493.27 0.00082648          1
    #> 4:    ask 60493.14 0.00001900          1
    #> 5:    ask 60492.56 0.00165071          1

At level 3 the third column is a character `order_id` instead of
`num_orders` (a single call returns one or the other, never both):

``` r

l3 <- market$get_orderbook("BTC-USD", level = 3L)
l3[, .(side, price, size, order_id)]
```

    #>        side    price       size                             order_id
    #>      <char>    <num>      <num>                               <char>
    #>   1:    bid 60481.81 0.01030000 10000000-0000-4000-8000-000000000000
    #>   2:    bid 60480.00 0.00560000 10000000-0000-4000-8000-000000000001
    #>   3:    bid 60478.70 0.01564455 10000000-0000-4000-8000-000000000002
    #>   4:    bid 60478.69 0.27476432 10000000-0000-4000-8000-000000000003
    #>   5:    bid 60478.00 0.00560000 10000000-0000-4000-8000-000000000004
    #>   6:    bid 60477.97 0.13227955 10000000-0000-4000-8000-000000000005
    #>   7:    bid 60477.84 0.00001900 10000000-0000-4000-8000-000000000006
    #>   8:    bid 60477.70 0.06613416 10000000-0000-4000-8000-000000000007
    #>   9:    bid 60477.61 0.04960714 10000000-0000-4000-8000-000000000008
    #>  10:    bid 60477.08 0.09926542 10000000-0000-4000-8000-000000000009
    #>  11:    bid 60477.08 0.06628080 10000000-0000-4000-8000-000000000010
    #>  12:    bid 60476.74 0.00248009 10000000-0000-4000-8000-000000000011
    #>  13:    bid 60476.00 0.00560000 10000000-0000-4000-8000-000000000012
    #>  14:    bid 60475.87 0.00017461 10000000-0000-4000-8000-000000000013
    #>  15:    bid 60475.52 0.12301469 10000000-0000-4000-8000-000000000014
    #>  16:    bid 60475.52 0.09280508 10000000-0000-4000-8000-000000000015
    #>  17:    bid 60475.25 0.09926542 10000000-0000-4000-8000-000000000016
    #>  18:    bid 60475.24 0.16553407 10000000-0000-4000-8000-000000000017
    #>  19:    bid 60475.06 0.00429929 10000000-0000-4000-8000-000000000018
    #>  20:    bid 60474.78 0.00001900 10000000-0000-4000-8000-000000000019
    #>  21:    bid 60474.63 0.00082661 10000000-0000-4000-8000-000000000020
    #>  22:    bid 60474.00 0.00560000 10000000-0000-4000-8000-000000000021
    #>  23:    bid 60473.10 0.04166679 10000000-0000-4000-8000-000000000022
    #>  24:    bid 60473.09 0.00454375 10000000-0000-4000-8000-000000000023
    #>  25:    bid 60472.06 0.11185704 10000000-0000-4000-8000-000000000024
    #>  26:    bid 60472.06 0.58269929 10000000-0000-4000-8000-000000000025
    #>  27:    bid 60472.05 0.06628080 10000000-0000-4000-8000-000000000026
    #>  28:    bid 60472.04 0.09926542 10000000-0000-4000-8000-000000000027
    #>  29:    bid 60472.00 0.00590000 10000000-0000-4000-8000-000000000028
    #>  30:    bid 60471.72 0.00001900 10000000-0000-4000-8000-000000000029
    #>  31:    bid 60471.00 1.00000000 10000000-0000-4000-8000-000000000030
    #>  32:    bid 60470.95 0.06789000 10000000-0000-4000-8000-000000000031
    #>  33:    bid 60470.62 0.00310011 10000000-0000-4000-8000-000000000032
    #>  34:    bid 60470.00 0.00590000 10000000-0000-4000-8000-000000000033
    #>  35:    bid 60470.00 0.01000000 10000000-0000-4000-8000-000000000034
    #>  36:    bid 60469.70 0.16553407 10000000-0000-4000-8000-000000000035
    #>  37:    bid 60469.68 0.21947960 10000000-0000-4000-8000-000000000036
    #>  38:    bid 60469.23 0.09926542 10000000-0000-4000-8000-000000000037
    #>  39:    bid 60468.66 0.00001900 10000000-0000-4000-8000-000000000038
    #>  40:    bid 60468.59 0.05274600 10000000-0000-4000-8000-000000000039
    #>  41:    bid 60468.12 0.05563684 10000000-0000-4000-8000-000000000040
    #>  42:    bid 60466.68 0.09926542 10000000-0000-4000-8000-000000000041
    #>  43:    bid 60466.62 0.00032994 10000000-0000-4000-8000-000000000042
    #>  44:    bid 60466.05 0.00592000 10000000-0000-4000-8000-000000000043
    #>  45:    bid 60465.60 0.00001900 10000000-0000-4000-8000-000000000044
    #>  46:    bid 60465.39 0.00004639 10000000-0000-4000-8000-000000000045
    #>  47:    bid 60465.01 0.02773620 10000000-0000-4000-8000-000000000046
    #>  48:    bid 60465.00 0.01000000 10000000-0000-4000-8000-000000000047
    #>  49:    bid 60464.99 0.03634998 10000000-0000-4000-8000-000000000048
    #>  50:    bid 60464.20 0.00009277 10000000-0000-4000-8000-000000000049
    #>  51:    ask 60481.82 0.05645871 20000000-0000-4000-8000-000000000000
    #>  52:    ask 60482.12 0.09926542 20000000-0000-4000-8000-000000000001
    #>  53:    ask 60483.96 0.06242556 20000000-0000-4000-8000-000000000002
    #>  54:    ask 60483.97 0.09926542 20000000-0000-4000-8000-000000000003
    #>  55:    ask 60484.00 0.00530000 20000000-0000-4000-8000-000000000004
    #>  56:    ask 60485.80 0.08204909 20000000-0000-4000-8000-000000000005
    #>  57:    ask 60485.80 0.10033507 20000000-0000-4000-8000-000000000006
    #>  58:    ask 60485.81 0.09926542 20000000-0000-4000-8000-000000000007
    #>  59:    ask 60485.82 0.13226241 20000000-0000-4000-8000-000000000008
    #>  60:    ask 60486.00 0.00530000 20000000-0000-4000-8000-000000000009
    #>  61:    ask 60486.77 0.06613416 20000000-0000-4000-8000-000000000010
    #>  62:    ask 60488.05 0.01564455 20000000-0000-4000-8000-000000000011
    #>  63:    ask 60488.06 0.19214145 20000000-0000-4000-8000-000000000012
    #>  64:    ask 60488.06 0.07613671 20000000-0000-4000-8000-000000000013
    #>  65:    ask 60488.07 0.09926542 20000000-0000-4000-8000-000000000014
    #>  66:    ask 60488.40 0.13225676 20000000-0000-4000-8000-000000000015
    #>  67:    ask 60488.41 0.00970000 20000000-0000-4000-8000-000000000016
    #>  68:    ask 60488.69 0.06628080 20000000-0000-4000-8000-000000000017
    #>  69:    ask 60489.18 0.06834000 20000000-0000-4000-8000-000000000018
    #>  70:    ask 60489.67 0.00009700 20000000-0000-4000-8000-000000000019
    #>  71:    ask 60489.99 0.09926542 20000000-0000-4000-8000-000000000020
    #>  72:    ask 60490.00 0.01000000 20000000-0000-4000-8000-000000000021
    #>  73:    ask 60490.00 0.00530000 20000000-0000-4000-8000-000000000022
    #>  74:    ask 60490.08 0.00001900 20000000-0000-4000-8000-000000000023
    #>  75:    ask 60491.07 0.00132219 20000000-0000-4000-8000-000000000024
    #>  76:    ask 60491.52 0.07415342 20000000-0000-4000-8000-000000000025
    #>  77:    ask 60491.52 0.04770563 20000000-0000-4000-8000-000000000026
    #>  78:    ask 60491.90 0.04166679 20000000-0000-4000-8000-000000000027
    #>  79:    ask 60492.00 0.00003167 20000000-0000-4000-8000-000000000028
    #>  80:    ask 60492.00 0.00530000 20000000-0000-4000-8000-000000000029
    #>  81:    ask 60492.05 0.01940000 20000000-0000-4000-8000-000000000030
    #>  82:    ask 60492.27 0.09926542 20000000-0000-4000-8000-000000000031
    #>  83:    ask 60493.14 0.00001900 20000000-0000-4000-8000-000000000032
    #>  84:    ask 60493.28 0.00019400 20000000-0000-4000-8000-000000000033
    #>  85:    ask 60493.77 0.05412215 20000000-0000-4000-8000-000000000034
    #>  86:    ask 60494.00 0.00590000 20000000-0000-4000-8000-000000000035
    #>  87:    ask 60494.28 0.14561142 20000000-0000-4000-8000-000000000036
    #>  88:    ask 60494.28 0.08020770 20000000-0000-4000-8000-000000000037
    #>  89:    ask 60494.29 0.09926542 20000000-0000-4000-8000-000000000038
    #>  90:    ask 60494.63 0.00583000 20000000-0000-4000-8000-000000000039
    #>  91:    ask 60494.76 0.16553407 20000000-0000-4000-8000-000000000040
    #>  92:    ask 60494.77 0.06628080 20000000-0000-4000-8000-000000000041
    #>  93:    ask 60495.00 0.01000000 20000000-0000-4000-8000-000000000042
    #>  94:    ask 60496.20 0.00001900 20000000-0000-4000-8000-000000000043
    #>  95:    ask 60497.33 0.83406652 20000000-0000-4000-8000-000000000044
    #>  96:    ask 60497.85 0.09926542 20000000-0000-4000-8000-000000000045
    #>  97:    ask 60498.00 1.00000000 20000000-0000-4000-8000-000000000046
    #>  98:    ask 60499.26 0.00001900 20000000-0000-4000-8000-000000000047
    #>  99:    ask 60499.26 0.00082640 20000000-0000-4000-8000-000000000048
    #> 100:    ask 60499.27 0.00235993 20000000-0000-4000-8000-000000000049
    #>        side    price       size                             order_id
    #>      <char>    <num>      <num>                               <char>

#### Ticker and server time

`get_ticker()` returns a single row; the numeric fields (`ask`, `bid`,
`price`, `size`, `volume`, `rfq_volume` where present) are cast to
`numeric` and the last-trade time to `POSIXct` in a `timestamp` column,
with any other fields (e.g. `trade_id`) left as the API sends them.

``` r

market$get_ticker("BTC-USD")[]
```

    #>         ask      bid   volume   trade_id    price    size rfq_volume
    #>       <num>    <num>    <num>      <int>    <num>   <num>      <num>
    #> 1: 60481.65 60481.64 5973.761 1045278653 60479.56 1.3e-07   67.01332
    #>              timestamp
    #>                 <POSc>
    #> 1: 2026-06-27 17:45:15

`get_server_time()` returns a single row with `iso` and `epoch`:

``` r

market$get_server_time()[]
```

    #>                         iso      epoch
    #>                      <char>      <num>
    #> 1: 2026-06-27T17:45:16.925Z 1782582317

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
| `get_portfolio_breakdown(portfolio_uuid, currency)` | `GET /api/v3/brokerage/portfolios/{uuid}` | one row per position |
| `get_portfolio_summary(portfolio_uuid, currency)` | `GET /api/v3/brokerage/portfolios/{uuid}` | single row |
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

    #>                                     uuid            name currency
    #>                                   <char>          <char>   <char>
    #>  1: 00000000-0000-4000-8000-000000000001     DASH Wallet     DASH
    #>  2: 00000000-0000-4000-8000-000000000003     ETH2 Wallet     ETH2
    #>  3: 00000000-0000-4000-8000-000000000004     COMP Wallet     COMP
    #>  4: 00000000-0000-4000-8000-000000000005     CGLD Wallet     CGLD
    #>  5: 00000000-0000-4000-8000-000000000006      GRT Wallet      GRT
    #>  6: 00000000-0000-4000-8000-000000000007      XLM Wallet      XLM
    #>  7: 00000000-0000-4000-8000-000000000008      BSV Wallet      BSV
    #>  8: 00000000-0000-4000-8000-000000000009      DAI Wallet      DAI
    #>  9: 00000000-0000-4000-8000-00000000000a      GNT Wallet      GNT
    #> 10: 00000000-0000-4000-8000-00000000000b      MKR Wallet      MKR
    #> 11: 00000000-0000-4000-8000-00000000000c      ZIL Wallet      ZIL
    #> 12: 00000000-0000-4000-8000-00000000000d      ZEC Wallet      ZEC
    #> 13: 00000000-0000-4000-8000-00000000000e      CVC Wallet      CVC
    #> 14: 00000000-0000-4000-8000-00000000000f      DNT Wallet      DNT
    #> 15: 00000000-0000-4000-8000-000000000010     MANA Wallet     MANA
    #> 16: 00000000-0000-4000-8000-000000000011     LOOM Wallet     LOOM
    #> 17: 00000000-0000-4000-8000-000000000012      BAT Wallet      BAT
    #> 18: 00000000-0000-4000-8000-000000000013     USDC Wallet     USDC
    #> 19: 00000000-0000-4000-8000-000000000014 PBVAONFR Wallet PBVAONFR
    #> 20: 00000000-0000-4000-8000-000000000015      ZRX Wallet      ZRX
    #> 21: 00000000-0000-4000-8000-000000000016      ETC Wallet      ETC
    #> 22: 00000000-0000-4000-8000-000000000017      BCH Wallet      BCH
    #> 23: 00000000-0000-4000-8000-000000000018      USD Wallet      USD
    #> 24: 00000000-0000-4000-8000-000000000019      LTC Wallet      LTC
    #> 25: 00000000-0000-4000-8000-00000000001a      ETH Wallet      ETH
    #> 26: 00000000-0000-4000-8000-00000000001b      BTC Wallet      BTC
    #>                                     uuid            name currency
    #>                                   <char>          <char>   <char>
    #>     available_balance  hold active default  ready                type
    #>                 <num> <num> <lgcl>  <lgcl> <lgcl>              <char>
    #>  1:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #>  2:               0.0     0   TRUE    TRUE  FALSE ACCOUNT_TYPE_CRYPTO
    #>  3:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #>  4:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #>  5:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #>  6:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #>  7:               0.0     0   TRUE    TRUE  FALSE ACCOUNT_TYPE_CRYPTO
    #>  8:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #>  9:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 10:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 11:               0.0     0   TRUE    TRUE  FALSE ACCOUNT_TYPE_CRYPTO
    #> 12:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 13:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 14:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 15:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 16:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 17:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 18:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 19:               0.0     0   TRUE    TRUE  FALSE ACCOUNT_TYPE_CRYPTO
    #> 20:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 21:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 22:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 23:               0.0     0   TRUE   FALSE   TRUE   ACCOUNT_TYPE_FIAT
    #> 24:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 25:               0.5     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #> 26:               0.0     0   TRUE    TRUE   TRUE ACCOUNT_TYPE_CRYPTO
    #>     available_balance  hold active default  ready                type
    #>                 <num> <num> <lgcl>  <lgcl> <lgcl>              <char>
    #>                      platform                  retail_portfolio_id
    #>                        <char>                               <char>
    #>  1: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #>  2: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #>  3: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #>  4: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #>  5: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #>  6: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #>  7: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #>  8: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #>  9: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 10: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 11: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 12: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 13: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 14: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 15: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 16: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 17: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 18: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 19: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 20: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 21: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 22: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 23: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 24: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 25: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #> 26: ACCOUNT_PLATFORM_CONSUMER 00000000-0000-4000-8000-000000000002
    #>                      platform                  retail_portfolio_id
    #>                        <char>                               <char>
    #>              created_at          updated_at
    #>                  <POSc>              <POSc>
    #>  1: 2025-03-17 06:44:24 2025-04-23 16:57:19
    #>  2: 2023-07-26 10:16:17 2023-07-26 10:16:18
    #>  3: 2020-12-24 21:42:52 2020-12-24 21:47:34
    #>  4: 2020-12-24 21:41:51 2020-12-24 21:48:21
    #>  5: 2020-12-24 21:39:42 2020-12-24 21:48:49
    #>  6: 2019-03-27 19:03:13 2025-03-17 07:14:40
    #>  7: 2019-03-06 08:25:49 2019-03-06 08:25:49
    #>  8: 2018-12-19 11:38:50 2018-12-19 11:38:50
    #>  9: 2018-12-19 11:38:50 2018-12-19 11:38:50
    #> 10: 2018-12-19 11:38:50 2020-12-24 21:48:02
    #> 11: 2018-12-19 11:38:50 2018-12-19 11:38:50
    #> 12: 2018-12-07 18:16:18 2018-12-07 18:16:19
    #> 13: 2018-12-07 18:16:17 2018-12-07 18:16:17
    #> 14: 2018-12-07 18:16:17 2018-12-07 18:16:17
    #> 15: 2018-12-07 18:16:17 2018-12-07 18:16:17
    #> 16: 2018-12-07 18:16:17 2018-12-07 18:16:17
    #> 17: 2018-11-06 11:12:35 2025-03-17 07:15:28
    #> 18: 2018-10-23 20:36:35 2026-06-09 17:12:16
    #> 19: 2018-10-23 20:36:35 2018-10-23 20:36:35
    #> 20: 2018-10-06 14:30:08 2018-10-06 14:30:08
    #> 21: 2018-02-08 02:10:29 2021-06-26 16:42:55
    #> 22: 2017-12-15 20:25:13 2017-12-17 15:21:56
    #> 23: 2017-11-29 20:27:22 2025-02-25 20:30:33
    #> 24: 2017-11-29 19:55:46 2025-03-15 01:15:34
    #> 25: 2017-11-29 19:55:46 2025-04-02 23:52:35
    #> 26: 2017-11-29 19:55:45 2026-02-01 05:45:36
    #>              created_at          updated_at
    #>                  <POSc>              <POSc>
    #>    currency available_balance  hold
    #>      <char>             <num> <num>
    #> 1:      ETH               0.5     0

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
    #> 1:      Intro 1          0.006          0.012       NA     NA            0
    #>    total_fees total_balance
    #>         <num>         <num>
    #> 1:          0             0

Pass `product_type = "SPOT"` or `"FUTURE"` to scope the summary.

#### Portfolios and key permissions

`get_portfolios()` returns one row per portfolio via the generic
`as_dt_list` flattener; `get_key_permissions()` returns a single row via
`as_dt_row`:

``` r

account$get_portfolios()[]
account$get_key_permissions()[]
```

    #>       name                                 uuid    type deleted
    #>     <char>                               <char>  <char>  <lgcl>
    #> 1: Default 00000000-0000-4000-8000-000000000002 DEFAULT   FALSE
    #>    can_view can_trade can_transfer                       portfolio_uuid
    #>      <lgcl>    <lgcl>       <lgcl>                               <char>
    #> 1:     TRUE      TRUE        FALSE 00000000-0000-4000-8000-000000000002
    #>    portfolio_type
    #>            <char>
    #> 1:        DEFAULT

#### Portfolio breakdown and totals

`get_portfolio_breakdown()` stacks a portfolio’s spot, futures, and
perpetual positions into one table, tagged by a `position_type` column,
with the concepts shared across types normalised to common columns
(`entry_price`, `mark_price`, `side`, `unrealized_pnl`) and the rest
kept under their API names. The aggregate totals are a separate one-row
table from `get_portfolio_summary()` (same endpoint) — no attributes, no
nested lists:

``` r

pf <- account$get_portfolios()$uuid[1L]
cols <- c("position_type", "product_id", "asset", "side", "entry_price", "mark_price", "unrealized_pnl")
account$get_portfolio_breakdown(pf)[, ..cols]
account$get_portfolio_summary(pf)[]
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
| `close_position(product_id, size, client_order_id)` | `POST /api/v3/brokerage/orders/close_position` | single row |

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
| `timestamp` | `POSIXct` (UTC) | order creation time (primary event time) |
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

    #>                                order_id product_id   side    status order_type
    #>                                  <char>     <char> <char>    <char>     <char>
    #> 1: 00000000-0000-4000-8000-00000000001c    LTC-USD    BUY CANCELLED      LIMIT
    #> 2: 00000000-0000-4000-8000-00000000001e    LTC-USD    BUY CANCELLED      LIMIT
    #> 3: 00000000-0000-4000-8000-000000000020   LTC-USDC    BUY CANCELLED      LIMIT
    #>        config_type filled_size
    #>             <char>       <num>
    #> 1: limit_limit_gtc           0
    #> 2: limit_limit_gtc           0
    #> 3: limit_limit_gtc           0

A single order by id is the same row shape:

``` r

trading$get_order("1111aaaa-2222-bbbb-3333-cccccccccccc")[
  , .(order_id, side, status, config_type, base_size, limit_price)
]
```

    #>                                order_id   side    status     config_type
    #>                                  <char> <char>    <char>          <char>
    #> 1: 00000000-0000-4000-8000-00000000001c    BUY CANCELLED limit_limit_gtc
    #>    base_size limit_price
    #>        <num>       <num>
    #> 1:        10          10

#### Fills (`get_fills`)

Parser `parse_fills`, one row per fill, exactly:

| Column                | Type            |
|-----------------------|-----------------|
| `entry_id`            | `character`     |
| `trade_id`            | `character`     |
| `order_id`            | `character`     |
| `product_id`          | `character`     |
| `side`                | `character`     |
| `timestamp`           | `POSIXct` (UTC) |
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
    #>              timestamp trade_type  price  size commission size_in_quote
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
| `timestamp`        | `POSIXct` (UTC)       |

``` r

futures$get_sweeps()[]
```

    #>            id requested_amount should_sweep_all  status  timestamp
    #>        <char>            <num>           <lgcl>  <char>     <POSc>
    #> 1: sweep-0001              500            FALSE PENDING 2026-05-31

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

    #>              margin_window_type            end_time
    #>                          <char>              <POSc>
    #> 1: MARGIN_WINDOW_TYPE_OVERNIGHT 2026-06-28 22:00:00
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
takes a `data.table` with `timestamp` (`POSIXct`), `price` (`numeric`),
and `size` (`numeric`) columns — exactly what `get_trades()` /
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

    #>               datetime     open     high      low    close    volume
    #>                 <POSc>    <num>    <num>    <num>    <num>     <num>
    #> 1: 2026-06-27 17:44:00 60502.78 60502.78 60499.26 60499.26 0.1652497
    #> 2: 2026-06-27 17:45:00 60499.26 60499.26 60475.36 60488.38 0.4092643

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
    #> [1] "5004c5b1-6251-4a2d-b0fc-d7093146dfbd"

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

    #>         ask      bid   volume   trade_id    price    size rfq_volume
    #>       <num>    <num>    <num>      <int>    <num>   <num>      <num>
    #> 1: 60481.65 60481.64 5973.761 1045278653 60479.56 1.3e-07   67.01332
    #>              timestamp
    #>                 <POSc>
    #> 1: 2026-06-27 17:45:15
    #>                 datetime     open     high      low    close    volume
    #>                   <POSc>    <num>    <num>    <num>    <num>     <num>
    #>   1: 2026-06-27 11:53:00 60239.24 60259.03 60237.18 60254.55 0.5974811
    #>   2: 2026-06-27 11:54:00 60254.55 60259.22 60245.28 60253.71 1.3447478
    #>   3: 2026-06-27 11:55:00 60253.71 60277.48 60253.35 60261.37 1.9928412
    #>   4: 2026-06-27 11:56:00 60261.37 60271.22 60261.37 60267.93 0.5881228
    #>   5: 2026-06-27 11:57:00 60267.94 60275.14 60267.93 60275.14 1.4672205
    #>  ---                                                                  
    #> 346: 2026-06-27 17:38:00 60488.71 60542.10 60486.43 60531.97 0.8154508
    #> 347: 2026-06-27 17:39:00 60531.98 60557.40 60490.84 60498.00 3.7195266
    #> 348: 2026-06-27 17:40:00 60499.25 60510.05 60490.08 60506.00 0.6947636
    #> 349: 2026-06-27 17:41:00 60506.00 60509.35 60494.01 60500.51 0.9226553
    #> 350: 2026-06-27 17:42:00 60500.51 60510.05 60500.51 60510.04 0.0020467

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

    #>  [1] 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
    #> [20] 0.0 0.0 0.0 0.0 0.0 0.5 0.0
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

    #>        side    price       size num_orders
    #>      <char>    <num>      <num>      <num>
    #>   1:    bid 60475.87 0.09089192          5
    #>   2:    bid 60475.43 0.04133910          1
    #>   3:    bid 60475.42 0.10519951          1
    #>   4:    bid 60475.36 0.01836163          3
    #>   5:    bid 60475.06 0.00429929          1
    #>   6:    bid 60474.78 0.00001900          1
    #>   7:    bid 60474.01 0.01564455          1
    #>   8:    bid 60474.00 0.00560000          1
    #>   9:    bid 60473.60 0.13228911          1
    #>  10:    bid 60472.66 0.15518089          1
    #>  11:    bid 60472.18 0.09926542          1
    #>  12:    bid 60472.00 0.00590000          1
    #>  13:    bid 60471.72 0.00001900          1
    #>  14:    bid 60471.51 0.04958465          1
    #>  15:    bid 60470.29 0.09926542          1
    #>  16:    bid 60470.00 0.00590000          1
    #>  17:    bid 60469.69 0.06628080          1
    #>  18:    bid 60469.68 0.81150667          2
    #>  19:    bid 60469.58 0.16553407          1
    #>  20:    bid 60469.50 1.00000000          1
    #>  21:    bid 60468.89 0.04166679          1
    #>  22:    bid 60468.66 0.00001900          1
    #>  23:    bid 60468.12 0.05563684          1
    #>  24:    bid 60468.09 0.09926542          1
    #>  25:    bid 60468.02 0.06799000          1
    #>  26:    bid 60466.62 0.00032994          1
    #>  27:    bid 60466.51 0.24033430          1
    #>  28:    bid 60466.26 0.09926542          1
    #>  29:    bid 60465.60 0.00001900          1
    #>  30:    bid 60465.39 0.00004639          1
    #>  31:    bid 60465.17 0.06144184          1
    #>  32:    bid 60465.00 0.01000000          1
    #>  33:    bid 60464.51 0.16553407          1
    #>  34:    bid 60464.20 0.00009277          1
    #>  35:    bid 60463.80 0.00001654          1
    #>  36:    bid 60463.54 0.14766813          1
    #>  37:    bid 60463.53 0.06628080          1
    #>  38:    bid 60463.52 0.09926542          1
    #>  39:    bid 60463.33 0.00908749          1
    #>  40:    bid 60462.92 0.07251205          1
    #>  41:    bid 60462.54 0.00001900          1
    #>  42:    bid 60461.84 0.00018554          1
    #>  43:    bid 60460.57 0.01817499          1
    #>  44:    bid 60460.41 0.00454375          1
    #>  45:    bid 60460.00 0.01000000          1
    #>  46:    bid 60459.48 0.00001900          1
    #>  47:    bid 60459.28 0.00583000          1
    #>  48:    bid 60459.27 0.19632383          1
    #>  49:    bid 60459.26 0.16553407          1
    #>  50:    bid 60459.16 0.09926542          1
    #>  51:    ask 60475.88 0.00248032          1
    #>  52:    ask 60476.05 0.00082678          1
    #>  53:    ask 60478.08 0.09926542          1
    #>  54:    ask 60478.29 0.06628080          1
    #>  55:    ask 60479.90 0.09926542          1
    #>  56:    ask 60480.00 0.00590000          1
    #>  57:    ask 60480.41 0.01564455          1
    #>  58:    ask 60480.42 0.00248032          1
    #>  59:    ask 60481.75 0.09926542          1
    #>  60:    ask 60481.96 0.35622262          2
    #>  61:    ask 60482.00 0.00590000          1
    #>  62:    ask 60482.03 0.13227071          1
    #>  63:    ask 60483.96 0.00001900          1
    #>  64:    ask 60484.00 0.00590000          1
    #>  65:    ask 60484.18 0.16553407          1
    #>  66:    ask 60484.19 0.09926542          1
    #>  67:    ask 60484.25 0.06628080          1
    #>  68:    ask 60484.43 0.16533181          1
    #>  69:    ask 60484.94 0.06613619          1
    #>  70:    ask 60485.00 0.01000000          1
    #>  71:    ask 60485.36 0.15718904          1
    #>  72:    ask 60486.00 0.00590000          1
    #>  73:    ask 60486.01 0.09926542          1
    #>  74:    ask 60486.82 0.01102322          1
    #>  75:    ask 60487.02 0.00001900          1
    #>  76:    ask 60487.16 0.00082678          1
    #>  77:    ask 60487.84 0.09926542          1
    #>  78:    ask 60487.99 0.20654011          1
    #>  79:    ask 60488.00 0.00590000          1
    #>  80:    ask 60488.05 0.04166679          1
    #>  81:    ask 60488.26 0.00132219          1
    #>  82:    ask 60488.41 0.00970000          1
    #>  83:    ask 60488.51 0.00310030          1
    #>  84:    ask 60489.14 0.00583000          1
    #>  85:    ask 60489.27 0.06828000          1
    #>  86:    ask 60489.67 0.00009700          1
    #>  87:    ask 60489.70 0.16553407          1
    #>  88:    ask 60489.71 0.06628080          1
    #>  89:    ask 60490.00 0.01000000          1
    #>  90:    ask 60490.08 0.00001900          1
    #>  91:    ask 60491.32 0.74961071          2
    #>  92:    ask 60491.39 0.06298625          1
    #>  93:    ask 60491.79 0.09926542          1
    #>  94:    ask 60492.00 1.00593167          3
    #>  95:    ask 60492.05 0.01940000          1
    #>  96:    ask 60492.56 0.00165071          1
    #>  97:    ask 60493.14 0.00001900          1
    #>  98:    ask 60493.27 0.00082648          1
    #>  99:    ask 60493.28 0.00019400          1
    #> 100:    ask 60493.74 0.09926542          1
    #>        side    price       size num_orders
    #>      <char>    <num>      <num>      <num>

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

    #> [1] 0.006
    #> [1] "Intro 1"
    #> [1] "limit_limit_gtc" "limit_limit_gtc" "limit_limit_gtc"
    #> [1] 10 10 10

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

Methods without a hand-written parser (`get_ticker`, `get_portfolios`,
`get_key_permissions`, `get_server_time`, `schedule_sweep`,
`cancel_sweep`, `get_intraday_margin_setting`) go through `as_dt_row` /
`as_dt_list`. These flatten every scalar field into a column and,
crucially, collapse any unexpected nested object/array or multi-element
value to a single JSON string — so even an endpoint the package doesn’t
model in detail still returns a list-column-free table. Recover such a
field with
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
  is what you asked for. The low-level
  [`coinbase_build_request()`](https://dereckscompany.github.io/coinbase/reference/coinbase_build_request.md)
  takes a `.perform` argument, so you can supply one that wraps the
  request in
  [`httr2::req_retry()`](https://httr2.r-lib.org/reference/req_retry.html)
  before performing it.

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

    #>      wallet currency available_balance futures_buying_power
    #>      <char>   <char>             <num>                <num>
    #>  1:    spot     DASH               0.0                   NA
    #>  2:    spot     ETH2               0.0                   NA
    #>  3:    spot     COMP               0.0                   NA
    #>  4:    spot     CGLD               0.0                   NA
    #>  5:    spot      GRT               0.0                   NA
    #>  6:    spot      XLM               0.0                   NA
    #>  7:    spot      BSV               0.0                   NA
    #>  8:    spot      DAI               0.0                   NA
    #>  9:    spot      GNT               0.0                   NA
    #> 10:    spot      MKR               0.0                   NA
    #> 11:    spot      ZIL               0.0                   NA
    #> 12:    spot      ZEC               0.0                   NA
    #> 13:    spot      CVC               0.0                   NA
    #> 14:    spot      DNT               0.0                   NA
    #> 15:    spot     MANA               0.0                   NA
    #> 16:    spot     LOOM               0.0                   NA
    #> 17:    spot      BAT               0.0                   NA
    #> 18:    spot     USDC               0.0                   NA
    #> 19:    spot PBVAONFR               0.0                   NA
    #> 20:    spot      ZRX               0.0                   NA
    #> 21:    spot      ETC               0.0                   NA
    #> 22:    spot      BCH               0.0                   NA
    #> 23:    spot      USD               0.0                   NA
    #> 24:    spot      LTC               0.0                   NA
    #> 25:    spot      ETH               0.5                   NA
    #> 26:    spot      BTC               0.0                   NA
    #> 27: futures     <NA>                NA                 9500
    #>      wallet currency available_balance futures_buying_power
    #>      <char>   <char>             <num>                <num>

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
