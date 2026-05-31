
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

    COINBASE_API_KEY_NAME="organizations/<org-uuid>/apiKeys/<key-uuid>"
    COINBASE_API_PRIVATE_KEY="-----BEGIN EC PRIVATE KEY-----\n...\n-----END EC PRIVATE KEY-----\n"

Public market data needs no credentials.

## Quick Start — Market Data (no auth)

``` r
box::use(coinbase[ CoinbaseMarketData, trades_to_ohlcv ])

market <- CoinbaseMarketData$new()

# Best bid/ask, OHLCV candles, recent trades, order book
market$get_ticker("BTC-USD")
market$get_ohlcv("BTC-USD", granularity = "1min")
market$get_trades("BTC-USD", limit = 100)
market$get_orderbook("BTC-USD", level = 2)

# Deep tick history -> aggregate to OHLCV at any timeframe
ticks <- market$get_trades_history("BTC-USD", start = Sys.time() - 3600)
bars <- trades_to_ohlcv(ticks, interval = 60)
```

## Account (auth)

``` r
box::use(coinbase[ CoinbaseAccount ])

account <- CoinbaseAccount$new()
account$get_accounts()         # balances (paginated)
account$get_fees()             # maker/taker fee tier
account$get_key_permissions()
```

## Trading

Always validate with a **preview** (which places nothing) before a live
order.

``` r
box::use(coinbase[ CoinbaseTrading ])

trading <- CoinbaseTrading$new()

# Dry run -- executes nothing
trading$preview_order(
  "BTC-USD", "BUY",
  list(market_market_ioc = list(quote_size = "10"))
)

# Live order (uncomment to place)
# trading$add_order(
#   "BTC-USD", "BUY",
#   list(limit_limit_gtc = list(base_size = "0.001", limit_price = "50000"))
# )

trading$get_orders(product_ids = "BTC-USD", limit = 10)
trading$get_fills(product_ids = "BTC-USD")
```

## US Futures (CFM) — the short leg

US residents short via CFTC-regulated futures (Coinbase Financial
Markets). Futures orders go through the same order endpoint with a
futures `product_id`; `CoinbaseFutures` manages the account, positions,
and margin.

``` r
box::use(coinbase[ CoinbaseFutures, CoinbaseTrading ])

futures <- CoinbaseFutures$new()
futures$get_balance_summary()
futures$get_positions()

# Open a short on a futures product
# CoinbaseTrading$new()$add_order(
#   "BIT-28FEB25-CDE", "SELL",
#   list(market_market_ioc = list(base_size = "1"))
# )
```

## Bulk Backfill

``` r
box::use(coinbase[ coinbase_backfill_trades ])

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
box::use(coinbase[ CoinbaseMarketData ], coro, later)

market <- CoinbaseMarketData$new(async = TRUE)

main <- coro$async(function() {
  ticker <- await(market$get_ticker("BTC-USD"))
  ohlcv <- await(market$get_ohlcv("BTC-USD", granularity = "1min"))

  print(ticker)
  print(ohlcv)
})

main()

# Drain the event loop until every promise has resolved.
while (!later$loop_empty()) {
  later$run_now()
}
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
