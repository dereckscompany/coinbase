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

    #>         ask      bid   volume   trade_id    price    size rfq_volume
    #>       <num>    <num>    <num>      <int>    <num>   <num>      <num>
    #> 1: 60481.65 60481.64 5973.761 1045278653 60479.56 1.3e-07   67.01332
    #>              timestamp
    #>                 <POSc>
    #> 1: 2026-06-27 17:45:15

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

    #>         ask      bid   volume   trade_id    price    size rfq_volume
    #>       <num>    <num>    <num>      <int>    <num>   <num>      <num>
    #> 1: 60481.65 60481.64 5973.761 1045278653 60479.56 1.3e-07   67.01332
    #>              timestamp
    #>                 <POSc>
    #> 1: 2026-06-27 17:45:15
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
    #> 1: 00000000-0000-4000-8000-00000000001c    LTC-USD    BUY CANCELLED      LIMIT
    #> 2: 00000000-0000-4000-8000-00000000001e    LTC-USD    BUY CANCELLED      LIMIT
    #> 3: 00000000-0000-4000-8000-000000000020   LTC-USDC    BUY CANCELLED      LIMIT
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
