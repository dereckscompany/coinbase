# Asynchronous Usage with coinbase

Every R6 class in `coinbase` accepts an `async = TRUE` flag at
construction. When enabled, all methods return
[`promises::promise`](https://rstudio.github.io/promises/reference/promise.html)
objects instead of direct values. This vignette shows how to consume
those promises with
[`coro::async`](https://coro.r-lib.org/reference/async.html)/`await` and
[`later::run_now`](https://later.r-lib.org/reference/run_now.html).

The examples below execute against a built-in mock of the Coinbase API,
so the printed output is real, deterministic data produced with no
network, no credentials, and no funds.

## Disclaimer

This software is provided for educational and research purposes. Trading
cryptocurrency carries substantial risk. You are solely responsible for
any orders placed through this package. Use the order **preview**
methods (which execute nothing) before placing live orders. The trading
examples below run against the public market-data host where they need
no auth; the order examples require credentials and are illustrative
only.

## Why Async?

Synchronous HTTP blocks the R session while waiting for a reply.
Asynchronous mode lets you fire off multiple requests and process
results as they arrive — useful for bots that poll several products or
place orders in parallel. The same `async` branch point covers every
class: `CoinbaseMarketData`, `CoinbaseAccount`, `CoinbaseTrading`, and
`CoinbaseFutures`.

## Setup

``` r

box::use(
  coinbase[CoinbaseMarketData, CoinbaseTrading, CoinbaseAccount, get_api_keys],
  coro[async, await],
  later[run_now, loop_empty],
  promises[then, catch, promise_all]
)
```

Public market data needs no credentials. For the authenticated classes,
store your CDP API key in `.Renviron` (the PEM newlines escaped as `\n`
on a single line) and let
[`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)
read them — never hardcode secrets:

``` bash
COINBASE_API_KEY_NAME="organizations/<org-uuid>/apiKeys/<key-uuid>"
COINBASE_API_PRIVATE_KEY="-----BEGIN EC PRIVATE KEY-----\n...\n-----END EC PRIVATE KEY-----\n"
```

``` r

keys <- get_api_keys()
```

> **Event loop**: R does not have a built-in event loop like Node.js or
> Python’s `asyncio`. Promises only resolve when the event loop ticks
> via
> [`later::run_now()`](https://later.r-lib.org/reference/run_now.html).
> In scripts and vignettes, drain the loop with
> `while (!loop_empty()) run_now()`. In **Shiny** apps the event loop
> runs automatically.

------------------------------------------------------------------------

## Basic Async: `coro::async` + `await`

The most ergonomic way to work with promises in R is
[`coro::async`](https://coro.r-lib.org/reference/async.html), which lets
you write code that *looks* synchronous but runs asynchronously under
the hood — just like TypeScript’s `async`/`await`. Pass `async = TRUE`
to any class constructor; its methods then return promises instead of
data.tables:

``` r

market <- CoinbaseMarketData$new(async = TRUE)
ticker <- NULL

get_ticker <- async(function() {
  res <- await(market$get_ticker("BTC-USD"))
  ticker <<- res
  return(invisible(NULL))
})

get_ticker()
while (!loop_empty()) {
  run_now()
}
ticker
```

    #>         ask   bid volume trade_id    price  size rfq_volume           timestamp
    #>       <num> <num>  <num>    <int>    <num> <num>      <num>              <POSc>
    #> 1: 50000.05 50000 1200.5  1000101 50000.02  0.01       12.5 2026-01-05 09:30:00

> **Key pattern**: define an `async` function, `await` each API call,
> capture the result with `<<-`, drive the event loop with
> `while (!loop_empty()) run_now()`.

The resolved value is a single-row `data.table` with numeric `ask`,
`bid`, `price`, `size`, `volume`, and a POSIXct `timestamp`.

------------------------------------------------------------------------

## Sequential Async: Multiple `await` Calls

Chain several awaited calls in sequence — each one resolves before the
next begins, just like `await` in TypeScript:

``` r

market <- CoinbaseMarketData$new(async = TRUE)
results <- NULL

fetch_data <- async(function() {
  ticker <- await(market$get_ticker("BTC-USD"))
  ohlcv <- await(market$get_ohlcv("BTC-USD", granularity = "1min"))
  results <<- list(ticker = ticker, ohlcv = ohlcv)
  return(invisible(NULL))
})

fetch_data()
while (!loop_empty()) {
  run_now()
}
results$ticker
results$ohlcv
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

The `ohlcv` element is a `data.table` with columns `datetime`, `open`,
`high`, `low`, `close`, `volume`.

------------------------------------------------------------------------

## Concurrent Requests with `promise_all`

When requests are independent, fire them simultaneously and collect all
results at once — the async equivalent of `Promise.all()` in TypeScript:

``` r

market <- CoinbaseMarketData$new(async = TRUE)
results <- NULL

fetch_parallel <- async(function() {
  # Launch both requests concurrently — no await yet, just collect promises
  ticker_promise <- market$get_ticker("BTC-USD")
  candles_promise <- market$get_ohlcv("BTC-USD", granularity = "1hour")
  # Await them together — like Promise.all([ticker, candles])
  res <- await(promise_all(ticker = ticker_promise, candles = candles_promise))
  results <<- res
  return(invisible(NULL))
})

fetch_parallel()
while (!loop_empty()) {
  run_now()
}
results$ticker
results$candles
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

## Practical Example: Polling Several Endpoints Concurrently

A common use case is gathering several views of a product at once — the
ticker, recent candles, recent trades, and the order book. With async
mode, all requests fly in parallel rather than sequentially:

``` r

market <- CoinbaseMarketData$new(async = TRUE)
snapshot <- NULL

fetch_snapshot <- async(function() {
  # Fire all requests concurrently
  promises <- list(
    ticker = market$get_ticker("BTC-USD"),
    candles = market$get_ohlcv("BTC-USD", granularity = "1min"),
    trades = market$get_trades("BTC-USD", limit = 100),
    orderbook = market$get_orderbook("BTC-USD", level = 2)
  )

  # Await all at once
  res <- await(do.call(promise_all, promises))
  snapshot <<- res
  return(invisible(NULL))
})

fetch_snapshot()
while (!loop_empty()) {
  run_now()
}

# Each element is the parsed data.table for one endpoint
snapshot$ticker
snapshot$orderbook
```

    #>         ask   bid volume trade_id    price  size rfq_volume           timestamp
    #>       <num> <num>  <num>    <int>    <num> <num>      <num>              <POSc>
    #> 1: 50000.05 50000 1200.5  1000101 50000.02  0.01       12.5 2026-01-05 09:30:00
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

The same `lapply` + `do.call(promise_all, ...)` shape scales to a
watchlist: build one promise per product, name the list by product id,
and await them together.

------------------------------------------------------------------------

## Promise Chaining with `then` / `catch`

If you prefer the promise-pipeline style (common in JavaScript), resolve
a promise with `then` and handle rejection with `catch`. This is the
alternative to
[`coro::async`](https://coro.r-lib.org/reference/async.html)/`await`:

``` r

market <- CoinbaseMarketData$new(async = TRUE)
chain_result <- NULL

stats_promise <- market$get_ohlcv("BTC-USD", granularity = "1hour")
handled <- then(stats_promise, function(ohlcv) {
  chain_result <<- ohlcv
  return(invisible(NULL))
})
catch(handled, function(err) {
  message("Error: ", conditionMessage(err))
  return(invisible(NULL))
})

while (!loop_empty()) {
  run_now()
}
chain_result
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

------------------------------------------------------------------------

## Async Trading Example

Trading methods return promises in async mode just like market data.
Always **preview** an order (a dry run that places nothing) before
submitting a live one. Sequential `await` keeps the flow readable.

Construct the client with your credentials (read from `.Renviron` via
[`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)):

``` r

trading <- CoinbaseTrading$new(async = TRUE)
```

``` r

results <- NULL

preview_then_query <- async(function() {
  # Dry run — executes nothing; validates the configuration
  preview <- await(trading$preview_order(
    "BTC-USD",
    "BUY",
    list(market_market_ioc = list(quote_size = "10"))
  ))

  # Query recent orders for this product
  orders <- await(trading$get_orders(product_ids = "BTC-USD", limit = 10))

  results <<- list(preview = preview, orders = orders)
  return(invisible(NULL))
})

preview_then_query()
while (!loop_empty()) {
  run_now()
}
results$preview[, .(order_total, commission_total, base_size, best_ask, errs)]
results$orders[, .(order_id, product_id, side, status, order_type, filled_size)]
```

    #>    order_total commission_total base_size best_ask   errs
    #>          <num>            <num>     <num>    <num> <char>
    #> 1:       10.06             0.06  0.000135 74101.53   <NA>
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

To place a live order, call `add_order()` instead of `preview_order()`.
It takes the same `product_id`, `side`, and `order_configuration`, plus
optional `client_order_id`, `self_trade_prevention_id`, `leverage`,
`margin_type`, and `retail_portfolio_id`; it resolves to a single-row
`data.table` with `success`, the scalar `order_id`, `product_id`,
`side`, `client_order_id`, and `failure_reason`.

------------------------------------------------------------------------

## Error Handling with `tryCatch`

Inside `async` functions, use `tryCatch` around `await` calls for
structured error handling — `await()` re-throws the promise rejection as
a normal R error, so the try/catch pattern works directly. Here a
malformed product id is rejected (validated before any request is sent)
and caught:

``` r

market <- CoinbaseMarketData$new(async = TRUE)
result <- NULL

safe_fetch <- async(function() {
  res <- tryCatch(
    await(market$get_ticker("NOTAVALIDSYMBOL")),
    error = function(e) {
      message("Caught error: ", conditionMessage(e))
      return(NULL)
    }
  )
  result <<- res
  return(invisible(NULL))
})

safe_fetch()
while (!loop_empty()) {
  run_now()
}
```

------------------------------------------------------------------------

## Running the Event Loop

The critical piece of async R is the **event loop**. Promises do not
resolve until the event loop ticks. In an interactive session or Shiny
app, the event loop runs automatically. In scripts or vignettes, you
must drive it manually.

``` r

# Idiomatic event loop drain
while (!later::loop_empty()) {
  later::run_now()
}
```

Or with a timeout guard:

``` r

deadline <- lubridate::now() + lubridate::seconds(30) # 30-second timeout
while (!later::loop_empty() && lubridate::now() < deadline) {
  later::run_now(timeoutSecs = 0.1)
}
```

In **Shiny** applications, the event loop is managed for you — simply
return promises from reactive expressions and Shiny handles resolution.

------------------------------------------------------------------------

## `coro::await` Cheat Sheet

| Pattern | Works? | Notes |
|----|----|----|
| `x <- await(promise)` | Yes | Standard pattern |
| `x <- await(obj$method(arg))` | Yes | Await wrapping a call is fine |
| `await(promise)` (bare, no assignment) | Yes | Side-effect only |
| `await` inside loops/if/tryCatch | Yes | Full control flow support |
| `x <<- await(promise)` | **No** | `<<-` not supported by coro |
| `f(await(promise))` | **No** | Nested inside function args |

> **Rule of thumb**: `await()` must appear as the RHS of a `<-` or as a
> bare statement — never inside another expression. Assign the result to
> a local with `<-`, then copy it out of the async body with `<<-` after
> the await returns.

------------------------------------------------------------------------

## Choosing Sync vs Async

| Scenario | Recommendation |
|----|----|
| Interactive exploration | **Sync** — simpler, results print immediately |
| Scripts fetching one endpoint | **Sync** — no event loop needed |
| Bots polling multiple products | **Async** — concurrent requests reduce latency |
| Shiny dashboards | **Async** — keeps the UI responsive |
| Deep tick backfills | Use `get_trades_history()` / [`coinbase_backfill_trades()`](https://dereckscompany.github.io/coinbase/reference/coinbase_backfill_trades.md) (handle batching internally) |

------------------------------------------------------------------------

## Next Steps

- See
  [`vignette("getting-started")`](https://dereckscompany.github.io/coinbase/articles/getting-started.md)
  for a tour of the package in synchronous mode.
- Review the `CoinbaseMarketData`, `CoinbaseAccount`, `CoinbaseTrading`,
  and `CoinbaseFutures` class documentation for full method coverage.
- Explore the [Coinbase Advanced Trade API
  documentation](https://docs.cdp.coinbase.com/advanced-trade/docs/welcome)
  for endpoint details.
