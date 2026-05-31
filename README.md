
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
#>         ask      bid   volume   trade_id    price    size                time
#>       <num>    <num>    <num>      <int>    <num>   <num>              <POSc>
#> 1: 74101.53 74101.52 3600.231 1026942323 74101.53 5.2e-07 2026-05-31 04:58:29
#>    rfq_volume
#>         <num>
#> 1:    10.7929
```

``` r
# OHLCV candles
market$get_ohlcv("BTC-USD", granularity = "1min")
#>               datetime     open     high      low    close volume
#>                 <POSc>    <num>    <num>    <num>    <num>  <num>
#> 1: 2026-05-31 04:53:00 74055.40 74070.12 74050.00 74067.15 1.4820
#> 2: 2026-05-31 04:54:00 74113.49 74113.49 74067.15 74068.26 3.0535
#> 3: 2026-05-31 04:55:00 74068.26 74093.61 74068.26 74093.60 0.9691
#> 4: 2026-05-31 04:56:00 74093.60 74099.83 74093.59 74099.83 0.1151
```

``` r
# Recent tick trades
market$get_trades("BTC-USD", limit = 100)
#>      trade_id   side    price       size                time
#>         <num> <char>    <num>      <num>              <POSc>
#> 1: 1026942323   sell 74101.53 0.00000052 2026-05-31 04:58:29
#> 2: 1026942322   sell 74101.53 0.00000240 2026-05-31 04:58:29
#> 3: 1026942321    buy 74101.54 0.00058315 2026-05-31 04:58:29
#> 4: 1026942320    buy 74100.98 0.01200000 2026-05-31 04:58:28
```

``` r
# Order book (top of book, aggregated)
market$get_orderbook("BTC-USD", level = 2)
#>      side    price       size num_orders
#>    <char>    <num>      <num>      <num>
#> 1:    bid 74101.52 0.43541938          5
#> 2:    bid 74101.38 0.00067474          1
#> 3:    bid 74098.69 0.00266800          1
#> 4:    ask 74101.53 0.08631688          7
#> 5:    ask 74103.63 0.26058806          2
#> 6:    ask 74103.66 0.00140588          2
```

Deep tick history pages the trades endpoint backwards in time; aggregate
the result to OHLCV at any timeframe with `trades_to_ohlcv()`:

``` r
ticks <- market$get_trades("BTC-USD", limit = 100)
bars <- trades_to_ohlcv(ticks, interval = 60)
bars[]
#>               datetime     open     high      low    close     volume
#>                 <POSc>    <num>    <num>    <num>    <num>      <num>
#> 1: 2026-05-31 04:58:00 74100.98 74101.54 74100.98 74101.53 0.01258607
```

## Account (auth)

``` r
account <- CoinbaseAccount$new()
```

``` r
# Balances across all wallets (paginated)
account$get_accounts()
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
```

``` r
# Maker/taker fee tier
account$get_fees()
#>    pricing_tier maker_fee_rate taker_fee_rate usd_from usd_to total_volume
#>          <char>          <num>          <num>    <num>  <num>        <num>
#> 1:   Advanced 1          0.004          0.006        0   1000     125000.5
#>    total_fees total_balance
#>         <num>         <num>
#> 1:     312.75      13050.42
```

``` r
account$get_key_permissions()
#>    can_view can_trade can_transfer                       portfolio_uuid
#>      <lgcl>    <lgcl>       <lgcl>                               <char>
#> 1:     TRUE      TRUE        FALSE 9c2f8b1e-1111-4d3a-9aaa-0123456789ab
#>    portfolio_type
#>            <char>
#> 1:        DEFAULT
```

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
#>    order_total commission_total quote_size base_size best_bid best_ask slippage
#>          <num>            <num>      <num>     <num>    <num>    <num>    <num>
#> 1:       10.06             0.06         10  0.000135 74101.52 74101.53    1e-04
#>      errs          preview_id
#>    <char>              <char>
#> 1:   <NA> prev-1234-5678-90ab
```

``` r
# Place an order (live -- against the mock here)
order <- trading$add_order(
  "BTC-USD", "BUY",
  list(limit_limit_gtc = list(base_size = "0.001", limit_price = "70000"))
)
order[]
#>    success                             order_id product_id   side
#>     <lgcl>                               <char>     <char> <char>
#> 1:    TRUE 1111aaaa-2222-bbbb-3333-cccccccccccc    BTC-USD    BUY
#>    client_order_id failure_reason       config_type base_size quote_size
#>             <char>         <char>            <char>     <num>      <num>
#> 1:      client-001           <NA> market_market_ioc        NA         10
#>    limit_price stop_price stop_trigger_price
#>          <num>      <num>              <num>
#> 1:          NA         NA                 NA
```

``` r
trading$get_orders(product_ids = "BTC-USD", limit = 10)
#>                                order_id client_order_id product_id   side
#>                                  <char>          <char>     <char> <char>
#> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc      client-001    BTC-USD    BUY
#> 2: 4444dddd-5555-eeee-6666-ffffffffffff      client-002    ETH-USD   SELL
#>    status order_type       config_type        time_in_force        created_time
#>    <char>     <char>            <char>               <char>              <POSc>
#> 1:   OPEN      LIMIT   limit_limit_gtc GOOD_UNTIL_CANCELLED 2026-05-30 18:30:00
#> 2: FILLED     MARKET market_market_ioc  IMMEDIATE_OR_CANCEL 2026-05-30 18:31:00
#>    completion_percentage filled_size average_filled_price number_of_fills
#>                    <num>       <num>                <num>           <num>
#> 1:                     0         0.0                  0.0               0
#> 2:                   100         0.5               3850.2               2
#>    filled_value total_fees base_size quote_size limit_price stop_price
#>           <num>      <num>     <num>      <num>       <num>      <num>
#> 1:          0.0        0.0     0.001         NA       70000         NA
#> 2:       1925.1        7.7     0.500         NA          NA         NA
#>    stop_trigger_price stop_direction end_time post_only
#>                 <num>         <char>   <POSc>    <lgcl>
#> 1:                 NA           <NA>     <NA>     FALSE
#> 2:                 NA           <NA>     <NA>        NA
```

``` r
trading$get_fills(product_ids = "ETH-USD")
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
```

``` r
# Edit an open order's price or size (preview first, then apply)
trading$preview_edit_order(order$order_id, price = "71000")
#>    errors slippage order_total commission_total quote_size base_size best_bid
#>    <char>    <num>       <num>            <num>      <num>     <num>    <num>
#> 1:   <NA>    2e-04       70.07             0.07         70     0.001 74101.52
#>    average_filled_price
#>                   <num>
#> 1:                    0
trading$edit_order(order$order_id, price = "71000")
#>    success                             order_id errors
#>     <lgcl>                               <char> <char>
#> 1:    TRUE 1111aaaa-2222-bbbb-3333-cccccccccccc   <NA>
```

``` r
trading$cancel_orders(order$order_id)
#>                                order_id success                failure_reason
#>                                  <char>  <lgcl>                        <char>
#> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc    TRUE UNKNOWN_CANCEL_FAILURE_REASON
```

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
```

``` r
futures$get_positions()
#>         product_id   side number_of_contracts current_price avg_entry_price
#>             <char> <char>               <num>         <num>           <num>
#> 1: BIT-31OCT26-CDE  SHORT                   3      74101.53           74500
#>    unrealized_pnl daily_realized_pnl     expiration_time
#>             <num>              <num>              <POSc>
#> 1:         -125.4               42.1 2026-10-31 16:00:00
```

``` r
futures$get_sweeps()
#>            id requested_amount should_sweep_all  status schedule_time
#>        <char>            <num>           <lgcl>  <char>        <POSc>
#> 1: sweep-0001              500            FALSE PENDING    2026-05-31
```

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
  from = as.POSIXct("2026-05-01", tz = "UTC"),
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
```

## Available Classes

| Class | Purpose | Auth |
|----|----|----|
| `CoinbaseMarketData` | products, OHLCV, trades, order book, ticker, deep history | No |
| `CoinbaseAccount` | balances, fees, portfolios, permissions | Yes |
| `CoinbaseTrading` | place / preview / edit / cancel / query orders and fills | Yes |
| `CoinbaseFutures` | US futures (CFM) balances, positions, margin, sweeps | Yes |

## License

MIT © Dereck Mezquita
