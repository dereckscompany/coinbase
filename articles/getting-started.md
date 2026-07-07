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

    #>         ask      bid   volume   trade_id    price    size rfq_volume
    #>       <num>    <num>    <num>      <int>    <num>   <num>      <num>
    #> 1: 60481.65 60481.64 5973.761 1045278653 60479.56 1.3e-07   67.01332
    #>              timestamp
    #>                 <POSc>
    #> 1: 2026-06-27 17:45:15

### OHLCV Candles

The `/candles` endpoint returns roughly 300 bars per call, so it is a
convenience for recent data. Valid granularities are `"1min"`, `"5min"`,
`"15min"`, `"1hour"`, `"6hour"`, and `"1day"`. The result has columns
`datetime`, `open`, `high`, `low`, `close`, `volume`:

``` r

candles <- market$get_ohlcv(product_id = "BTC-USD", granularity = "1min")
candles[]
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

### Recent Trades

Recent tick trades, with columns `trade_id`, `side`, `price`, `size`,
`timestamp`:

``` r

trades <- market$get_trades(product_id = "BTC-USD", limit = 100)
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

### Order Book

A snapshot at level `1` (best bid/ask), `2` (top 50 aggregated), or `3`
(full, non-aggregated). The result is a long table with a `side` column:

``` r

book <- market$get_orderbook(product_id = "BTC-USD", level = 2)
book[]
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

### Server Time

``` r

st <- market$get_server_time()
st[]
```

    #>                         iso      epoch
    #>                      <char>      <num>
    #> 1: 2026-06-27T17:45:16.925Z 1782582317

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

    #>    product_id      open      high       low      last   volume volume_30day
    #>        <char>     <num>     <num>     <num>     <num>    <num>        <num>
    #> 1:    ACS-USD 0.0001301 0.0001326 0.0001279 0.0001301 88776224   7098703559
    #> 2:    ADA-USD 0.1479000 0.1495000 0.1462000 0.1470000 33304644   2645295188
    #> 3:   AGLD-USD 0.2024000 0.2693000 0.1900000 0.2130000 16906534     35805427
    #> 4:    ACH-USD 0.0044930 0.0045140 0.0043560 0.0044430  8928341    775255314
    #> 5:   AERO-USD 0.4785200 0.4855200 0.4660600 0.4716400  4733990    324013616
    #>    product_id   open   high    low   last      volume volume_30day     change
    #>        <char>  <num>  <num>  <num>  <num>       <num>        <num>      <num>
    #> 1:   AGLD-USD 0.2024 0.2693 0.1900 0.2130 16906533.53     35805427 0.05237154
    #> 2:    AKT-USD 0.6550 0.6880 0.6400 0.6710   766898.25     61476034 0.02442748
    #> 3:    ABT-USD 0.1982 0.2185 0.1967 0.2027   296372.40      7484549 0.02270434
    #> 4:     A8-USD 0.0052 0.0053 0.0052 0.0053   356898.23    171785546 0.01923077
    #> 5:  1INCH-GBP 0.0520 0.0530 0.0520 0.0530     6574.01       830755 0.01923077

For a single product, `get_product_stats()` also carries the
RFQ/conversion volumes:

``` r

market$get_product_stats("BTC-USD")[]
```

    #>     open     high      low     last   volume volume_30day rfq_volume_24hour
    #>    <num>    <num>    <num>    <num>    <num>        <num>             <num>
    #> 1: 59929 60838.92 59448.68 60502.77 5973.761     294050.4          67.01332
    #>    rfq_volume_30day conversions_volume_24hour conversions_volume_30day
    #>               <num>                     <num>                    <num>
    #> 1:         2620.291                        NA                       NA

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

    #>    product_id bid_price  bid_size ask_price ask_size           timestamp
    #>        <char>     <num>     <num>     <num>    <num>              <POSc>
    #> 1:    BTC-USD  60438.32 0.2639901  60438.33 0.005282 2026-06-27 18:58:27

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

    #>                                     uuid currency available_balance  hold
    #>                                   <char>   <char>             <num> <num>
    #>  1: 00000000-0000-4000-8000-000000000001     DASH               0.0     0
    #>  2: 00000000-0000-4000-8000-000000000003     ETH2               0.0     0
    #>  3: 00000000-0000-4000-8000-000000000004     COMP               0.0     0
    #>  4: 00000000-0000-4000-8000-000000000005     CGLD               0.0     0
    #>  5: 00000000-0000-4000-8000-000000000006      GRT               0.0     0
    #>  6: 00000000-0000-4000-8000-000000000007      XLM               0.0     0
    #>  7: 00000000-0000-4000-8000-000000000008      BSV               0.0     0
    #>  8: 00000000-0000-4000-8000-000000000009      DAI               0.0     0
    #>  9: 00000000-0000-4000-8000-00000000000a      GNT               0.0     0
    #> 10: 00000000-0000-4000-8000-00000000000b      MKR               0.0     0
    #> 11: 00000000-0000-4000-8000-00000000000c      ZIL               0.0     0
    #> 12: 00000000-0000-4000-8000-00000000000d      ZEC               0.0     0
    #> 13: 00000000-0000-4000-8000-00000000000e      CVC               0.0     0
    #> 14: 00000000-0000-4000-8000-00000000000f      DNT               0.0     0
    #> 15: 00000000-0000-4000-8000-000000000010     MANA               0.0     0
    #> 16: 00000000-0000-4000-8000-000000000011     LOOM               0.0     0
    #> 17: 00000000-0000-4000-8000-000000000012      BAT               0.0     0
    #> 18: 00000000-0000-4000-8000-000000000013     USDC               0.0     0
    #> 19: 00000000-0000-4000-8000-000000000014 PBVAONFR               0.0     0
    #> 20: 00000000-0000-4000-8000-000000000015      ZRX               0.0     0
    #> 21: 00000000-0000-4000-8000-000000000016      ETC               0.0     0
    #> 22: 00000000-0000-4000-8000-000000000017      BCH               0.0     0
    #> 23: 00000000-0000-4000-8000-000000000018      USD               0.0     0
    #> 24: 00000000-0000-4000-8000-000000000019      LTC               0.0     0
    #> 25: 00000000-0000-4000-8000-00000000001a      ETH               0.5     0
    #> 26: 00000000-0000-4000-8000-00000000001b      BTC               0.0     0
    #>                                     uuid currency available_balance  hold
    #>                                   <char>   <char>             <num> <num>
    #>                    type
    #>                  <char>
    #>  1: ACCOUNT_TYPE_CRYPTO
    #>  2: ACCOUNT_TYPE_CRYPTO
    #>  3: ACCOUNT_TYPE_CRYPTO
    #>  4: ACCOUNT_TYPE_CRYPTO
    #>  5: ACCOUNT_TYPE_CRYPTO
    #>  6: ACCOUNT_TYPE_CRYPTO
    #>  7: ACCOUNT_TYPE_CRYPTO
    #>  8: ACCOUNT_TYPE_CRYPTO
    #>  9: ACCOUNT_TYPE_CRYPTO
    #> 10: ACCOUNT_TYPE_CRYPTO
    #> 11: ACCOUNT_TYPE_CRYPTO
    #> 12: ACCOUNT_TYPE_CRYPTO
    #> 13: ACCOUNT_TYPE_CRYPTO
    #> 14: ACCOUNT_TYPE_CRYPTO
    #> 15: ACCOUNT_TYPE_CRYPTO
    #> 16: ACCOUNT_TYPE_CRYPTO
    #> 17: ACCOUNT_TYPE_CRYPTO
    #> 18: ACCOUNT_TYPE_CRYPTO
    #> 19: ACCOUNT_TYPE_CRYPTO
    #> 20: ACCOUNT_TYPE_CRYPTO
    #> 21: ACCOUNT_TYPE_CRYPTO
    #> 22: ACCOUNT_TYPE_CRYPTO
    #> 23:   ACCOUNT_TYPE_FIAT
    #> 24: ACCOUNT_TYPE_CRYPTO
    #> 25: ACCOUNT_TYPE_CRYPTO
    #> 26: ACCOUNT_TYPE_CRYPTO
    #>                    type
    #>                  <char>

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
    #> 1: 00000000-0000-4000-8000-00000000001c    LTC-USD    BUY CANCELLED      LIMIT
    #> 2: 00000000-0000-4000-8000-00000000001e    LTC-USD    BUY CANCELLED      LIMIT
    #> 3: 00000000-0000-4000-8000-000000000020   LTC-USDC    BUY CANCELLED      LIMIT
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
