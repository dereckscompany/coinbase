
# coinbase

R API wrapper to the Coinbase Advanced Trade API supporting both
synchronous and asynchronous (promise based) operations. Provides R6
classes for market data, spot trading, account management, and US
futures (CFM), with helpers for tick-to-OHLCV aggregation.

## Disclaimer

This software is provided for educational and research purposes. Trading
cryptocurrency carries substantial risk. You are solely responsible for
any orders placed through this package. Use the order **preview**
methods (which execute nothing) before placing live orders.

## Design Philosophy

- **`data.table` everywhere, no list columns.** Every method returns a
  flat `data.table`; nested API objects are flattened into scalar
  columns.
- **Sync and async.** Every method works in both modes. `async = TRUE`
  returns a \[promise\]\[promises::promise\]; otherwise results are
  returned directly. There is a single sync/async branch point.
- **Exact money values.** Prices, sizes, and amounts are transmitted
  with full precision (never rounded or in scientific notation).
- **Two hosts.** Authenticated trading/account endpoints use the
  Advanced Trade host (`api.coinbase.com`); deep public market data uses
  the Exchange host (`api.exchange.coinbase.com`).

## Installation

``` r
# install.packages("remotes")
remotes::install_github("dereckscompany/coinbase")
```

## Setup

Create API credentials at <https://www.coinbase.com/settings/api>
(download the JSON with a `name` and a `privateKey`). Store them as
environment variables in `.Renviron` — the PEM newlines escaped as `\n`
on a single line (see `.Renviron.example`):

``` bash
COINBASE_API_KEY_NAME="organizations/<org-uuid>/apiKeys/<key-uuid>"
COINBASE_API_PRIVATE_KEY="-----BEGIN EC PRIVATE KEY-----\n...\n-----END EC PRIVATE KEY-----\n"
```

Load them with `get_api_keys()` (reads the two environment variables by
default):

``` r
box::use(coinbase[ get_api_keys ])

keys <- get_api_keys()
```

Public market data needs no credentials.

## Quick Start — Market Data (no auth)

``` r
market <- CoinbaseMarketData$new()

# Best bid/ask
market$get_ticker("BTC-USD")
```

    #>         ask      bid   volume   trade_id    price    size                time
    #>       <num>    <num>    <num>      <int>    <num>   <num>              <POSc>
    #> 1: 60481.65 60481.64 5973.761 1045278653 60479.56 1.3e-07 2026-06-27 17:45:15
    #>    rfq_volume
    #>         <num>
    #> 1:   67.01332

``` r
# OHLCV candles
market$get_ohlcv("BTC-USD", granularity = "1min")
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

``` r
# Recent tick trades
market$get_trades("BTC-USD", limit = 100)
```

    #>        trade_id   side    price       size                time
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
    #>        trade_id   side    price       size                time
    #>           <num> <char>    <num>      <num>              <POSc>

``` r
# Order book (top of book, aggregated)
market$get_orderbook("BTC-USD", level = 2)
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

``` r
# 24h stats for every product in one call -- rank it yourself for a
# movers / most-active scanner
stats <- market$get_stats()
head(stats[order(-volume)], 5)
```

    #>    product_id      open      high       low      last   volume volume_30day
    #>        <char>     <num>     <num>     <num>     <num>    <num>        <num>
    #> 1:    ACS-USD 0.0001301 0.0001326 0.0001279 0.0001301 88776224   7098703559
    #> 2:    ADA-USD 0.1479000 0.1495000 0.1462000 0.1470000 33304644   2645295188
    #> 3:   AGLD-USD 0.2024000 0.2693000 0.1900000 0.2130000 16906534     35805427
    #> 4:    ACH-USD 0.0044930 0.0045140 0.0043560 0.0044430  8928341    775255314
    #> 5:   AERO-USD 0.4785200 0.4855200 0.4660600 0.4716400  4733990    324013616

Deep tick history pages the trades endpoint backwards in time; aggregate
the result to OHLCV at any timeframe with `trades_to_ohlcv()`:

``` r
ticks <- market$get_trades("BTC-USD", limit = 100)
bars <- trades_to_ohlcv(ticks, interval = 60)
bars[]
```

    #>               datetime     open     high      low    close    volume
    #>                 <POSc>    <num>    <num>    <num>    <num>     <num>
    #> 1: 2026-06-27 17:44:00 60502.78 60502.78 60499.26 60499.26 0.1652497
    #> 2: 2026-06-27 17:45:00 60499.26 60499.26 60475.36 60488.38 0.4092643

## Account (auth)

``` r
account <- CoinbaseAccount$new()
```

``` r
# Balances across all wallets (paginated)
account$get_accounts()
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

``` r
# Maker/taker fee tier
account$get_fees()
```

    #>    pricing_tier maker_fee_rate taker_fee_rate usd_from usd_to total_volume
    #>          <char>          <num>          <num>    <num>  <num>        <num>
    #> 1:      Intro 1          0.006          0.012       NA     NA            0
    #>    total_fees total_balance
    #>         <num>         <num>
    #> 1:          0             0

``` r
account$get_key_permissions()
```

    #>    can_view can_trade can_transfer                       portfolio_uuid
    #>      <lgcl>    <lgcl>       <lgcl>                               <char>
    #> 1:     TRUE      TRUE        FALSE 00000000-0000-4000-8000-000000000002
    #>    portfolio_type
    #>            <char>
    #> 1:        DEFAULT

## Trading

Always validate with a **preview** (which places nothing) before a live
order.

``` r
trading <- CoinbaseTrading$new()
```

``` r
# Dry run -- executes nothing
trading$preview_order(
  "BTC-USD", "BUY",
  list(market_market_ioc = list(quote_size = "10"))
)
```

    #>    order_total commission_total quote_size base_size best_bid best_ask slippage
    #>          <num>            <num>      <num>     <num>    <num>    <num>    <num>
    #> 1:       10.06             0.06         10  0.000135 74101.52 74101.53    1e-04
    #>      errs          preview_id
    #>    <char>              <char>
    #> 1:   <NA> prev-1234-5678-90ab

``` r
# Place an order (live -- against the mock here)
order <- trading$add_order(
  "BTC-USD", "BUY",
  list(limit_limit_gtc = list(base_size = "0.001", limit_price = "70000"))
)
order[]
```

    #>    success                             order_id product_id   side
    #>     <lgcl>                               <char>     <char> <char>
    #> 1:    TRUE 1111aaaa-2222-bbbb-3333-cccccccccccc    BTC-USD    BUY
    #>    client_order_id failure_reason       config_type base_size quote_size
    #>             <char>         <char>            <char>     <num>      <num>
    #> 1:      client-001           <NA> market_market_ioc        NA         10
    #>    limit_price stop_price stop_trigger_price
    #>          <num>      <num>              <num>
    #> 1:          NA         NA                 NA

``` r
trading$get_orders(product_ids = "BTC-USD", limit = 10)
```

    #>                                order_id                      client_order_id
    #>                                  <char>                               <char>
    #> 1: 00000000-0000-4000-8000-00000000001c 00000000-0000-4000-8000-00000000001d
    #> 2: 00000000-0000-4000-8000-00000000001e 00000000-0000-4000-8000-00000000001f
    #> 3: 00000000-0000-4000-8000-000000000020 00000000-0000-4000-8000-000000000021
    #>    product_id   side    status order_type     config_type        time_in_force
    #>        <char> <char>    <char>     <char>          <char>               <char>
    #> 1:    LTC-USD    BUY CANCELLED      LIMIT limit_limit_gtc GOOD_UNTIL_CANCELLED
    #> 2:    LTC-USD    BUY CANCELLED      LIMIT limit_limit_gtc GOOD_UNTIL_CANCELLED
    #> 3:   LTC-USDC    BUY CANCELLED      LIMIT limit_limit_gtc GOOD_UNTIL_CANCELLED
    #>           created_time completion_percentage filled_size average_filled_price
    #>                 <POSc>                 <num>       <num>                <num>
    #> 1: 2025-02-03 02:45:09                     0           0                    0
    #> 2: 2025-02-03 02:38:33                     0           0                    0
    #> 3: 2025-02-03 02:33:31                     0           0                    0
    #>    number_of_fills filled_value total_fees base_size quote_size limit_price
    #>              <num>        <num>      <num>     <num>      <num>       <num>
    #> 1:               0            0          0        10         NA          10
    #> 2:               0            0          0        10         NA          10
    #> 3:               0            0          0        10         NA          10
    #>    stop_price stop_trigger_price stop_direction end_time post_only
    #>         <num>              <num>         <char>   <POSc>    <lgcl>
    #> 1:         NA                 NA           <NA>     <NA>      TRUE
    #> 2:         NA                 NA           <NA>     <NA>      TRUE
    #> 3:         NA                 NA           <NA>     <NA>     FALSE

``` r
trading$get_fills(product_ids = "ETH-USD")
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

``` r
# Edit an open order's price or size (preview first, then apply)
trading$preview_edit_order(order$order_id, price = "71000")
trading$edit_order(order$order_id, price = "71000")
```

    #>    errors slippage order_total commission_total quote_size base_size best_bid
    #>    <char>    <num>       <num>            <num>      <num>     <num>    <num>
    #> 1:   <NA>    2e-04       70.07             0.07         70     0.001 74101.52
    #>    average_filled_price
    #>                   <num>
    #> 1:                    0
    #>    success                             order_id errors
    #>     <lgcl>                               <char> <char>
    #> 1:    TRUE 1111aaaa-2222-bbbb-3333-cccccccccccc   <NA>

``` r
trading$cancel_orders(order$order_id)
```

    #>                                order_id success                failure_reason
    #>                                  <char>  <lgcl>                        <char>
    #> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc    TRUE UNKNOWN_CANCEL_FAILURE_REASON

## US Futures (CFM) — the short leg

US residents short via CFTC-regulated futures (Coinbase Financial
Markets). Futures orders go through the same order endpoint with a
futures `product_id`; `CoinbaseFutures` manages the account, positions,
and margin.

``` r
futures <- CoinbaseFutures$new()
```

``` r
futures$get_balance_summary()
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

``` r
futures$get_positions()
```

    #>         product_id   side number_of_contracts current_price avg_entry_price
    #>             <char> <char>               <num>         <num>           <num>
    #> 1: BIT-31OCT26-CDE  SHORT                   3      74101.53           74500
    #>    unrealized_pnl daily_realized_pnl     expiration_time
    #>             <num>              <num>              <POSc>
    #> 1:         -125.4               42.1 2026-10-31 16:00:00

``` r
futures$get_sweeps()
```

    #>            id requested_amount should_sweep_all  status schedule_time
    #>        <char>            <num>           <lgcl>  <char>        <POSc>
    #> 1: sweep-0001              500            FALSE PENDING    2026-05-31

``` r
# Open a short on a futures product (live -- placed through CoinbaseTrading)
# CoinbaseTrading$new()$add_order(
#   "BIT-31OCT26-CDE", "SELL",
#   list(market_market_ioc = list(base_size = "1"))
# )
```

## Bulk Backfill

``` r
# Walks trades back to `from`, writes CSV incrementally, resumes if re-run.
coinbase_backfill_trades(
  symbols = c("BTC-USD", "ETH-USD"),
  from = lubridate::as_datetime("2026-05-01", tz = "UTC"),
  file = "trades.csv"
)
```

## Asynchronous Use

The package is written around promises for non-blocking, event-loop use
(à la JavaScript). Pass `async = TRUE` to any class and its methods
return a \[promise\]\[promises::promise\] instead of a `data.table`.
Resolve it with `$then()` chaining or, as recommended, `coro::async()` /
`await()` for sequential-looking code, and drive the event loop with
[later](https://r-lib.github.io/later/).

``` r
market_async <- CoinbaseMarketData$new(async = TRUE)

main <- coro$async(function() {
  ticker <- await(market_async$get_ticker("BTC-USD"))
  ohlcv <- await(market_async$get_ohlcv("BTC-USD", granularity = "1min"))

  print(ticker)
  print(ohlcv)
})

main()

# Drain the event loop until every promise has resolved.
while (!later$loop_empty()) {
  later$run_now()
}
```

    #>         ask      bid   volume   trade_id    price    size                time
    #>       <num>    <num>    <num>      <int>    <num>   <num>              <POSc>
    #> 1: 60481.65 60481.64 5973.761 1045278653 60479.56 1.3e-07 2026-06-27 17:45:15
    #>    rfq_volume
    #>         <num>
    #> 1:   67.01332
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

## Available Classes

| Class | Purpose | Auth |
|----|----|----|
| `CoinbaseMarketData` | products, OHLCV, trades, order book, ticker, deep history | No |
| `CoinbaseAccount` | balances, fees, portfolios, permissions | Yes |
| `CoinbaseTrading` | place / preview / edit / cancel / query orders and fills | Yes |
| `CoinbaseFutures` | US futures (CFM) balances, positions, margin, sweeps | Yes |

## License

MIT © Dereck Mezquita
