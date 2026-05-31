# Shorting with US Futures (CFM) with coinbase

This vignette covers going **short** through Coinbase Financial Markets
(CFM) US futures using the `coinbase` package. Coinbase spot is
long-only — you cannot sell a coin you do not hold — so the headline
route to a short position for a US customer is a `SELL` order on a CFM
futures contract. Unlike crypto exchanges that expose a separate futures
order endpoint, Coinbase places **futures orders through the same order
endpoint as spot**: you submit them with `CoinbaseTrading$add_order()`
using a futures `product_id`. The `CoinbaseFutures` class manages the
surrounding account state — balances, positions, cash sweeps, and
intraday margin.

> **Disclaimer — leverage and liquidation risk.** Futures are leveraged
> instruments. A short position has theoretically unbounded loss: if the
> underlying rises, your loss grows without limit, and the position can
> be **liquidated** the moment your equity falls below the maintenance
> threshold, crystallising losses that may exceed your initial margin.
> Funding, fees, and contract expiry add further risk. Every order below
> is shown as a **dry-run preview** — nothing here ever transmits a live
> order. Trade futures only with risk capital you can afford to lose,
> and never run a live order example without understanding it fully.

## Why CFM futures for shorting

| Venue | Direction | Wrapped here? |
|----|----|----|
| Coinbase spot (CBI) | Long only | Yes (`CoinbaseTrading`, spot `product_id`) |
| CFM US futures | Long **and short** | Yes (orders via `CoinbaseTrading`; account via `CoinbaseFutures`) |
| INTX perpetuals (`/intx/*`) | Long and short | No — non-US jurisdictions only, intentionally excluded |

US customers trade the CFM futures covered by this package. Coinbase’s
INTX perpetual-futures endpoints are for eligible non-US jurisdictions
and are not wrapped. To open a short, you submit a `SELL` order on a CFM
futures product (an expiring contract such as a nano-BTC future);
`CoinbaseFutures` then reports the resulting position, margin, and PnL.

This complements the `alpaca` package, which trades long US equities:
holding long stocks in `alpaca` while shorting a correlated crypto
future on CFM is the building block of a pairs / statistical-arbitrage
strategy spanning the two brokers.

## Setup

Credentials come from the Coinbase Developer Platform (a JSON file with
a `name` and a `privateKey`). Store them in `.Renviron` as
`COINBASE_API_KEY_NAME` and `COINBASE_API_PRIVATE_KEY`; the multi-line
`privateKey` is placed on one line with its newlines escaped as the two
characters `\n`, which
[`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)
unescapes before signing. The CFM futures account also requires separate
approval and funding on Coinbase.

``` bash
# In ~/.Renviron (these are obviously-fake placeholders — never commit real keys):
COINBASE_API_KEY_NAME="organizations/<org-uuid>/apiKeys/<key-uuid>"
COINBASE_API_PRIVATE_KEY="-----BEGIN EC PRIVATE KEY-----\n<fake-key-body>\n-----END EC PRIVATE KEY-----\n"
```

With those set,
[`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)
reads them with no arguments, so you simply construct each client and
the credentials are picked up automatically. Public market data needs no
credentials at all.

``` r

box::use(
  coinbase[
    CoinbaseTrading, CoinbaseFutures, CoinbaseMarketData, get_api_keys
  ]
)

keys <- get_api_keys()

market <- CoinbaseMarketData$new()
trading <- CoinbaseTrading$new(keys = keys)
futures <- CoinbaseFutures$new(keys = keys)
```

------------------------------------------------------------------------

## CFM Futures Account State

`CoinbaseFutures` manages everything around the position. It does
**not** place orders itself — orders go through `CoinbaseTrading` (see
below).

### Balance Summary

The balance summary is the first thing to check before shorting: it
reports your futures buying power, the margin already committed,
unrealised PnL, and — most importantly — your liquidation threshold and
buffer.

``` r

summary <- futures$get_balance_summary()
summary[, .(
  futures_buying_power,        # buying power available for futures orders
  cfm_usd_balance,             # USD held in the CFM (futures) account
  cbi_usd_balance,             # USD held in the spot (CBI) account
  initial_margin,              # margin committed to open positions
  available_margin,            # margin still free
  unrealized_pnl,              # mark-to-market PnL on open positions
  liquidation_threshold,       # equity level at which positions are liquidated
  liquidation_buffer_amount,   # cushion above the threshold
  liquidation_buffer_percentage
)]
```

    #>    futures_buying_power cfm_usd_balance cbi_usd_balance initial_margin
    #>                   <num>           <num>           <num>          <num>
    #> 1:                 9500            8000            2000            740
    #>    available_margin unrealized_pnl liquidation_threshold
    #>               <num>          <num>                 <num>
    #> 1:             7260         -125.4                   370
    #>    liquidation_buffer_amount liquidation_buffer_percentage
    #>                        <num>                         <num>
    #> 1:                      7630                          95.4

### Open Positions

`get_positions()` returns every open CFM position; a short shows `side`
of `"SHORT"` with negative unrealised PnL when the contract price rises.

``` r

positions <- futures$get_positions()
positions[, .(
  product_id, side, number_of_contracts,
  avg_entry_price, current_price,
  unrealized_pnl, daily_realized_pnl, expiration_time
)]
```

    #>         product_id   side number_of_contracts avg_entry_price current_price
    #>             <char> <char>               <num>           <num>         <num>
    #> 1: BIT-31OCT26-CDE  SHORT                   3           74500      74101.53
    #>    unrealized_pnl daily_realized_pnl     expiration_time
    #>             <num>              <num>              <POSc>
    #> 1:         -125.4               42.1 2026-10-31 16:00:00

Query a single contract by its product ID:

``` r

pos <- futures$get_position(product_id = "BIT-31OCT26-CDE")
pos[, .(product_id, side, number_of_contracts, avg_entry_price, unrealized_pnl)]
```

    #>         product_id   side number_of_contracts avg_entry_price unrealized_pnl
    #>             <char> <char>               <num>           <num>          <num>
    #> 1: BIT-31OCT26-CDE  SHORT                   3           74500         -125.4

### Cash Sweeps (CFM \<-\> Spot)

Cash moves between the spot (CBI) wallet and the futures (CFM) account
through scheduled sweeps. Schedule a sweep of USD from futures back to
spot, list pending sweeps, and cancel the pending sweep:

``` r

# Schedule a sweep of $100 from the CFM futures account to the spot USD wallet
scheduled <- futures$schedule_sweep(usd_amount = 100)
scheduled[]

# List scheduled and pending sweeps
sweeps <- futures$get_sweeps()
sweeps[, .(id, requested_amount, should_sweep_all, status, schedule_time)]

# Cancel the pending sweep
futures$cancel_sweep()[]
```

    #>    success
    #>     <lgcl>
    #> 1:    TRUE
    #>            id requested_amount should_sweep_all  status schedule_time
    #>        <char>            <num>           <lgcl>  <char>        <POSc>
    #> 1: sweep-0001              500            FALSE PENDING    2026-05-31
    #>    success
    #>     <lgcl>
    #> 1:    TRUE

### Intraday Margin

Read and set your intraday margin setting. Intraday margin lowers the
margin requirement during the trading session (raising effective
leverage, and risk); the standard setting applies the full requirement.

``` r

# Current setting
futures$get_intraday_margin_setting()[]

# Switch to intraday margin (raises leverage and liquidation risk)
futures$set_intraday_margin_setting(setting = "INTRADAY_MARGIN_SETTING_INTRADAY")[]

# Switch back to the standard (full) margin requirement
futures$set_intraday_margin_setting(setting = "INTRADAY_MARGIN_SETTING_STANDARD")[]
```

    #>                             setting
    #>                              <char>
    #> 1: INTRADAY_MARGIN_SETTING_STANDARD
    #>                             setting
    #>                              <char>
    #> 1: INTRADAY_MARGIN_SETTING_INTRADAY
    #>                             setting
    #>                              <char>
    #> 1: INTRADAY_MARGIN_SETTING_STANDARD

Check the current margin window — whether intraday margin is presently
active and when it ends. The killswitch flags indicate whether Coinbase
has disabled intraday margin or new enrollment:

``` r

window <- futures$get_current_margin_window(
  margin_profile_type = "MARGIN_PROFILE_TYPE_RETAIL_INTRADAY_MARGIN_1"
)
window[, .(
  margin_window_type, end_time,
  is_intraday_margin_killswitch_enabled,
  is_intraday_margin_enrollment_killswitch_enabled
)]
```

    #>                  margin_window_type            end_time
    #>                              <char>              <POSc>
    #> 1: FCM_MARGIN_WINDOW_TYPE_OVERNIGHT 2026-05-31 13:30:00
    #>    is_intraday_margin_killswitch_enabled
    #>                                   <lgcl>
    #> 1:                                 FALSE
    #>    is_intraday_margin_enrollment_killswitch_enabled
    #>                                              <lgcl>
    #> 1:                                            FALSE

------------------------------------------------------------------------

## Finding a Futures Product

Futures products appear in the same product catalogue as spot. List the
products and pick out the expiring CFM contracts — their IDs carry an
expiry (e.g. `BIT-31OCT26-CDE`):

``` r

products <- market$get_products()
products[, .(id, status)]
```

    #>         id status
    #>     <char> <char>
    #> 1: BTC-USD online
    #> 2: ETH-USD online
    #> 3: SOL-USD online

Inspect a single contract’s metadata before trading it. The same
`get_product()` call works for an expiring CFM contract by passing its
futures `product_id`:

``` r

contract <- market$get_product(product_id = "BIT-31OCT26-CDE")
contract[]
```

------------------------------------------------------------------------

## Opening a Short (Preview Only)

A short is simply a **`SELL` order on a futures `product_id`**, placed
through `CoinbaseTrading$add_order()` — the very same method used for
spot. The order configuration follows the standard one-key form
(`market_market_ioc`, `limit_limit_gtc`, etc.), where the key names the
detailed order type and the inner list carries the sizes/prices.

**We will not place a live short here.** Use `preview_order()` first: it
is a dry run that validates the configuration and returns the estimated
total, commission, sizes, and any errors — and **places nothing**.

### Preview a Market Short

``` r

preview <- trading$preview_order(
  product_id = "BIT-31OCT26-CDE",
  side = "SELL",                                    # SELL on a future = open short
  order_configuration = list(
    market_market_ioc = list(base_size = "1")       # 1 contract
  )
)
preview[, .(order_total, commission_total, base_size, best_bid, best_ask, slippage, errs)]
```

    #>    order_total commission_total base_size best_bid best_ask slippage   errs
    #>          <num>            <num>     <num>    <num>    <num>    <num> <char>
    #> 1:       10.06             0.06  0.000135 74101.52 74101.53    1e-04   <NA>

### Preview a Limit Short with Leverage and Margin Type

`add_order()` and `preview_order()` accept `leverage`, `margin_type`
(`"CROSS"` or `"ISOLATED"`), and `retail_portfolio_id`. Higher leverage
means a closer liquidation threshold — preview the numbers before
committing:

``` r

preview <- trading$preview_order(
  product_id = "BIT-31OCT26-CDE",
  side = "SELL",
  order_configuration = list(
    limit_limit_gtc = list(
      base_size = "1",
      limit_price = "95000"
    )
  ),
  leverage = "2",
  margin_type = "CROSS"
)
preview[, .(order_total, commission_total, base_size, best_bid, best_ask, errs, preview_id)]
```

    #>    order_total commission_total base_size best_bid best_ask   errs
    #>          <num>            <num>     <num>    <num>    <num> <char>
    #> 1:       10.06             0.06  0.000135 74101.52 74101.53   <NA>
    #>             preview_id
    #>                 <char>
    #> 1: prev-1234-5678-90ab

### Placing the Live Short (Use With Extreme Caution)

Only when the preview is satisfactory would you place the live order.
This is a real, leveraged, short position — it can be liquidated. The
example is left `eval = FALSE` and shown purely for completeness:

``` r

order <- trading$add_order(
  product_id = "BIT-31OCT26-CDE",
  side = "SELL",
  order_configuration = list(
    limit_limit_gtc = list(
      base_size = "1",
      limit_price = "95000"
    )
  ),
  leverage = "2",
  margin_type = "CROSS"
)
order[, .(success, order_id, product_id, side, failure_reason)]
```

`add_order()` also accepts `self_trade_prevention_id` (preview does not)
and a `client_order_id` idempotency key, which defaults to a fresh UUID
via
[`generate_client_order_id()`](https://dereckscompany.github.io/coinbase/reference/generate_client_order_id.md).

------------------------------------------------------------------------

## Managing the Short

### Inspect Open Futures Orders

`get_orders()` filters historical orders; pass `product_type = "FUTURE"`
to scope to futures and `order_side = "SELL"` for the short legs:

``` r

open_shorts <- trading$get_orders(
  product_type = "FUTURE",
  order_side = "SELL",
  order_status = "OPEN",
  limit = 50
)
open_shorts[, .(order_id, product_id, side, status, base_size, limit_price, created_time)]
```

    #>                                order_id product_id   side status base_size
    #>                                  <char>     <char> <char> <char>     <num>
    #> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc    BTC-USD    BUY   OPEN     0.001
    #> 2: 4444dddd-5555-eeee-6666-ffffffffffff    ETH-USD   SELL FILLED     0.500
    #>    limit_price        created_time
    #>          <num>              <POSc>
    #> 1:       70000 2026-05-30 18:30:00
    #> 2:          NA 2026-05-30 18:31:00

### Fills

`get_fills()` reports executions. Filter by `order_ids` (plural),
`trade_ids`, or `product_ids`:

``` r

fills <- trading$get_fills(
  product_ids = "BIT-31OCT26-CDE",
  sort_by = "TRADE_TIME"
)
fills[, .(trade_id, order_id, product_id, side, price, size, commission, trade_time)]
```

    #>      trade_id                             order_id product_id   side  price
    #>        <char>                               <char>     <char> <char>  <num>
    #> 1: trade-0001 4444dddd-5555-eeee-6666-ffffffffffff    ETH-USD   SELL 3850.2
    #> 2: trade-0002 4444dddd-5555-eeee-6666-ffffffffffff    ETH-USD   SELL 3850.2
    #>     size commission          trade_time
    #>    <num>      <num>              <POSc>
    #> 1:   0.3       4.62 2026-05-30 18:31:02
    #> 2:   0.2       3.08 2026-05-30 18:31:03

### Edit or Cancel

Reprice or resize an open short, or cancel it outright:

``` r

# Move the limit short to a new price
trading$edit_order(order_id = "1111aaaa-2222-bbbb-3333-cccccccccccc", price = 96000)

# Cancel one or more orders
trading$cancel_orders(order_ids = "1111aaaa-2222-bbbb-3333-cccccccccccc")
```

    #>    success                             order_id errors
    #>     <lgcl>                               <char> <char>
    #> 1:    TRUE 1111aaaa-2222-bbbb-3333-cccccccccccc   <NA>
    #>                                order_id success                failure_reason
    #>                                  <char>  <lgcl>                        <char>
    #> 1: 1111aaaa-2222-bbbb-3333-cccccccccccc    TRUE UNKNOWN_CANCEL_FAILURE_REASON

### Closing the Short

The idiomatic way to flatten a position is `close_position()`, which
submits the offsetting order for you. Pass the futures `product_id`, and
optionally a `size` to close only part of the position (omit `size` to
close all of it):

``` r

closed <- trading$close_position(product_id = "BIT-31OCT26-CDE", size = "1")
closed[, .(success, order_id, product_id, side)]
```

    #>    success                             order_id      product_id   side
    #>     <lgcl>                               <char>          <char> <char>
    #> 1:    TRUE 4444dddd-5555-eeee-6666-ffffffffffff BIT-28FEB25-CDE    BUY

You can also close manually by submitting the opposite side — a `BUY`
order on the same futures product, for the same number of contracts.
Preview it first:

``` r

preview <- trading$preview_order(
  product_id = "BIT-31OCT26-CDE",
  side = "BUY",                                     # BUY closes (covers) the short
  order_configuration = list(
    market_market_ioc = list(base_size = "1")
  )
)
preview[, .(order_total, commission_total, base_size, errs)]
```

    #>    order_total commission_total base_size   errs
    #>          <num>            <num>     <num> <char>
    #> 1:       10.06             0.06  0.000135   <NA>

------------------------------------------------------------------------

## Pairs Trading with alpaca

A common use of this short leg is a market-neutral pair: hold a long
US-equity position in `alpaca` and short a correlated crypto future on
CFM. The two brokers are driven independently — `alpaca` for the long
stock leg, `coinbase` for the short futures leg — and each reports its
own positions and PnL:

``` r

# Long leg (alpaca): buy the equity
# alpaca_trading$add_order(symbol = "COIN", side = "buy", type = "market",
#   time_in_force = "day", qty = 100)

# Short leg (coinbase CFM): preview the offsetting futures short
trading$preview_order(
  product_id = "BIT-31OCT26-CDE",
  side = "SELL",
  order_configuration = list(market_market_ioc = list(base_size = "1"))
)[, .(order_total, commission_total, base_size, errs)]
```

    #>    order_total commission_total base_size   errs
    #>          <num>            <num>     <num> <char>
    #> 1:       10.06             0.06  0.000135   <NA>

Monitor both legs’ exposure: the equity position via `alpaca`’s account
methods, and the futures short via `futures$get_positions()` and
`futures$get_balance_summary()`.

------------------------------------------------------------------------

## Async Usage

Every method runs asynchronously when the client is constructed with
`async = TRUE`, returning a promise. Consume promises with
[`coro::async()`](https://coro.r-lib.org/reference/async.html) and
`await()`, and drain the event loop yourself — without any pipe
operator:

``` r

box::use(coro[async, await], later)

futures_async <- CoinbaseFutures$new(keys = keys, async = TRUE)
```

``` r

run <- async(function() {
  summary <- await(futures_async$get_balance_summary())
  positions <- await(futures_async$get_positions())
  print(summary[, .(futures_buying_power, available_margin, liquidation_threshold)])
  print(positions[, .(product_id, side, number_of_contracts, unrealized_pnl)])
  return(invisible(NULL))
})

run()

# Drive the event loop until the promise settles
while (!later$loop_empty()) {
  later$run_now()
}
```

    #>    futures_buying_power available_margin liquidation_threshold
    #>                   <num>            <num>                 <num>
    #> 1:                 9500             7260                   370
    #>         product_id   side number_of_contracts unrealized_pnl
    #>             <char> <char>               <num>          <num>
    #> 1: BIT-31OCT26-CDE  SHORT                   3         -125.4

------------------------------------------------------------------------

## Method Reference

### CoinbaseFutures

| Method | Description |
|----|----|
| `get_balance_summary()` | Buying power, margin, unrealised PnL, liquidation thresholds |
| `get_positions()` | All open CFM futures positions |
| `get_position(product_id)` | A single position by product |
| `schedule_sweep(usd_amount)` | Schedule a cash sweep from CFM to spot |
| `get_sweeps()` | Scheduled and pending sweeps |
| `cancel_sweep()` | Cancel the pending sweep |
| `get_intraday_margin_setting()` | Current intraday margin setting |
| `set_intraday_margin_setting(setting)` | Set intraday/standard margin |
| `get_current_margin_window(margin_profile_type)` | Current margin window and killswitch flags |

### CoinbaseTrading (used for futures orders)

| Method | Description |
|----|----|
| `add_order(product_id, side, order_configuration, ...)` | Place an order; `SELL` on a future opens a short. Accepts `leverage`, `margin_type`, `self_trade_prevention_id`, `retail_portfolio_id`, `client_order_id` |
| `preview_order(product_id, side, order_configuration, ...)` | Dry-run validation; places nothing. Accepts `leverage`, `margin_type`, `retail_portfolio_id` |
| `get_order(order_id)` | A single order by ID |
| `get_orders(...)` | Historical orders; filter by `product_type`, `order_side`, `order_status`, `order_ids`, `start_date`, `end_date`, `order_types`, `sort_by`, … |
| `get_fills(...)` | Historical fills; filter by `order_ids`, `trade_ids`, `product_ids`, sequence-timestamp bounds, `sort_by` |
| `edit_order(order_id, price, size)` | Reprice/resize an open order |
| `preview_edit_order(order_id, price, size)` | Dry-run an edit |
| `cancel_orders(order_ids)` | Cancel one or more orders |

## Next Steps

- See
  [`vignette("getting-started")`](https://dereckscompany.github.io/coinbase/articles/getting-started.md)
  for basic market data and order placement.
- See
  [`vignette("data-shapes")`](https://dereckscompany.github.io/coinbase/articles/data-shapes.md)
  for the exact columns each call returns.
- Consult the [Coinbase Advanced Trade API
  documentation](https://docs.cdp.coinbase.com/advanced-trade/docs/welcome)
  for full endpoint details and the current CFM contract universe.
