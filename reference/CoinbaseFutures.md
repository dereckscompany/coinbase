# CoinbaseFutures: US Futures (CFM) Account, Positions, and Margin

CoinbaseFutures: US Futures (CFM) Account, Positions, and Margin

CoinbaseFutures: US Futures (CFM) Account, Positions, and Margin

## Details

Manages the Coinbase Financial Markets (CFM) US futures account: balance
summary, open positions, cash sweeps between the spot (CBI) and futures
(CFM) accounts, and intraday margin settings. All endpoints require
credentials and a funded, approved CFM futures account.

Inherits from
[CoinbaseBase](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md).
All methods support both synchronous and asynchronous execution
depending on the `async` argument at construction.

### Placing futures orders (the short leg)

Futures **orders are placed through the same order endpoint as spot** —
use
[CoinbaseTrading](https://dereckscompany.github.io/coinbase/reference/CoinbaseTrading.md)
with a futures `product_id` and a futures order configuration. To open a
short, submit a `SELL` order on the futures product (e.g. a nano-BTC
contract). This class manages the surrounding account state (margin,
positions, balances, sweeps); it does not place orders itself.

## Note on perpetuals

Coinbase's INTX perpetual-futures endpoints (`/intx/*`) are for eligible
**non-US** jurisdictions and are intentionally not wrapped here; US
customers trade the CFM futures covered by this class.

### Endpoints Covered

|  |  |  |
|----|----|----|
| Method | Endpoint | Auth |
| get_balance_summary | GET /api/v3/brokerage/cfm/balance_summary | Yes |
| get_positions | GET /api/v3/brokerage/cfm/positions | Yes |
| get_position | GET /api/v3/brokerage/cfm/positions/{id} | Yes |
| schedule_sweep | POST /api/v3/brokerage/cfm/sweeps/schedule | Yes |
| get_sweeps | GET /api/v3/brokerage/cfm/sweeps | Yes |
| cancel_sweep | DELETE /api/v3/brokerage/cfm/sweeps | Yes |
| get_intraday_margin_setting | GET /api/v3/brokerage/cfm/intraday/margin_setting | Yes |
| set_intraday_margin_setting | POST /api/v3/brokerage/cfm/intraday/margin_setting | Yes |
| get_current_margin_window | GET /api/v3/brokerage/cfm/intraday/current_margin_window | Yes |

## Super classes

[`connectcore::RestClient`](https://rdrr.io/pkg/connectcore/man/RestClient.html)
-\>
[`coinbase::CoinbaseBase`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md)
-\> `CoinbaseFutures`

## Methods

### Public methods

- [`CoinbaseFutures$get_balance_summary()`](#method-CoinbaseFutures-get_balance_summary)

- [`CoinbaseFutures$get_positions()`](#method-CoinbaseFutures-get_positions)

- [`CoinbaseFutures$get_position()`](#method-CoinbaseFutures-get_position)

- [`CoinbaseFutures$schedule_sweep()`](#method-CoinbaseFutures-schedule_sweep)

- [`CoinbaseFutures$get_sweeps()`](#method-CoinbaseFutures-get_sweeps)

- [`CoinbaseFutures$cancel_sweep()`](#method-CoinbaseFutures-cancel_sweep)

- [`CoinbaseFutures$get_intraday_margin_setting()`](#method-CoinbaseFutures-get_intraday_margin_setting)

- [`CoinbaseFutures$set_intraday_margin_setting()`](#method-CoinbaseFutures-set_intraday_margin_setting)

- [`CoinbaseFutures$get_current_margin_window()`](#method-CoinbaseFutures-get_current_margin_window)

- [`CoinbaseFutures$clone()`](#method-CoinbaseFutures-clone)

Inherited methods

- [`coinbase::CoinbaseBase$initialize()`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.html#method-initialize)

------------------------------------------------------------------------

### Method `get_balance_summary()`

Retrieve the CFM futures balance summary (buying power, margin,
unrealised PnL, liquidation thresholds).

#### Usage

    CoinbaseFutures$get_balance_summary()

#### Returns

(FuturesBalance \| promise\<FuturesBalance\>) a single-row table, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_positions()`

Retrieve all open CFM futures positions.

#### Usage

    CoinbaseFutures$get_positions()

#### Returns

(FuturesPositions \| promise\<FuturesPositions\>) the positions, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_position()`

Retrieve a single CFM futures position by product.

#### Usage

    CoinbaseFutures$get_position(product_id)

#### Arguments

- `product_id`:

  (scalar\<character\>) the futures product ID.

#### Returns

(FuturesPositions \| promise\<FuturesPositions\>) a single-row table, or
a promise thereof.

------------------------------------------------------------------------

### Method `schedule_sweep()`

Schedule a cash sweep from the CFM futures account to the spot (CBI) USD
wallet.

#### Usage

    CoinbaseFutures$schedule_sweep(usd_amount)

#### Arguments

- `usd_amount`:

  (scalar\<numeric\> \| scalar\<character\>) positive amount in USD to
  sweep.

#### Returns

(data.table \| promise\<data.table\>) a single-row table, or a promise
thereof.

- success (logical) whether the sweep was scheduled.

------------------------------------------------------------------------

### Method `get_sweeps()`

Retrieve scheduled and pending futures sweeps.

#### Usage

    CoinbaseFutures$get_sweeps()

#### Returns

(FuturesSweeps \| promise\<FuturesSweeps\>) the sweeps, or a promise
thereof.

------------------------------------------------------------------------

### Method `cancel_sweep()`

Cancel the pending futures sweep.

#### Usage

    CoinbaseFutures$cancel_sweep()

#### Returns

(data.table \| promise\<data.table\>) a single-row table, or a promise
thereof.

- success (logical) whether the pending sweep was cancelled.

------------------------------------------------------------------------

### Method `get_intraday_margin_setting()`

Retrieve the current intraday margin setting.

#### Usage

    CoinbaseFutures$get_intraday_margin_setting()

#### Returns

(data.table \| promise\<data.table\>) a single-row table, or a promise
thereof.

- setting (character) the active intraday-margin setting.

------------------------------------------------------------------------

### Method `set_intraday_margin_setting()`

Set the intraday margin setting.

#### Usage

    CoinbaseFutures$set_intraday_margin_setting(setting)

#### Arguments

- `setting`:

  (scalar\<character\>) e.g. `"INTRADAY_MARGIN_SETTING_STANDARD"` or
  `"INTRADAY_MARGIN_SETTING_INTRADAY"`.

#### Returns

(data.table \| promise\<data.table\>) a single-row table echoing the
applied `setting` (the API returns an empty body on success; a non-200
aborts), or a promise thereof.

- setting (character) the applied intraday-margin setting.

------------------------------------------------------------------------

### Method `get_current_margin_window()`

Retrieve the current margin window.

#### Usage

    CoinbaseFutures$get_current_margin_window(margin_profile_type)

#### Arguments

- `margin_profile_type`:

  (scalar\<character\>) the margin profile type (required by the API),
  e.g. `"MARGIN_PROFILE_TYPE_RETAIL_INTRADAY_MARGIN_1"`.

#### Returns

(MarginWindow \| promise\<MarginWindow\>) a single-row table, or a
promise thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CoinbaseFutures$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
futures <- CoinbaseFutures$new()
futures$get_balance_summary()
futures$get_positions()
# Open a short via the shared order endpoint:
# CoinbaseTrading$new()$add_order("BIT-28FEB25-CDE", "SELL",
#   list(market_market_ioc = list(base_size = "1")))
} # }
```
