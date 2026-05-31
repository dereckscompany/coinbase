# CoinbaseFutures: US Futures (CFM) Account, Positions, and Margin

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

## Super class

[`CoinbaseBase`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md)
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

- [`CoinbaseBase$initialize()`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.html#method-initialize)

------------------------------------------------------------------------

### `CoinbaseFutures$get_balance_summary()`

Retrieve the CFM futures balance summary (buying power, margin,
unrealised PnL, liquidation thresholds).

#### Usage

    CoinbaseFutures$get_balance_summary()

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseFutures$get_positions()`

Retrieve all open CFM futures positions.

#### Usage

    CoinbaseFutures$get_positions()

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of positions, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseFutures$get_position()`

Retrieve a single CFM futures position by product.

#### Usage

    CoinbaseFutures$get_position(product_id)

#### Arguments

- `product_id`:

  Character; the futures product ID.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseFutures$schedule_sweep()`

Schedule a cash sweep from the CFM futures account to the spot (CBI) USD
wallet.

#### Usage

    CoinbaseFutures$schedule_sweep(usd_amount)

#### Arguments

- `usd_amount`:

  Character/numeric; positive amount in USD to sweep.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseFutures$get_sweeps()`

Retrieve scheduled and pending futures sweeps.

#### Usage

    CoinbaseFutures$get_sweeps()

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of sweeps, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseFutures$cancel_sweep()`

Cancel the pending futures sweep.

#### Usage

    CoinbaseFutures$cancel_sweep()

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseFutures$get_intraday_margin_setting()`

Retrieve the current intraday margin setting.

#### Usage

    CoinbaseFutures$get_intraday_margin_setting()

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseFutures$set_intraday_margin_setting()`

Set the intraday margin setting.

#### Usage

    CoinbaseFutures$set_intraday_margin_setting(setting)

#### Arguments

- `setting`:

  Character; e.g. `"INTRADAY_MARGIN_SETTING_STANDARD"` or
  `"INTRADAY_MARGIN_SETTING_INTRADAY"`.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
echoing the applied `setting` (the API returns an empty body on success;
a non-200 aborts), or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseFutures$get_current_margin_window()`

Retrieve the current margin window.

#### Usage

    CoinbaseFutures$get_current_margin_window(margin_profile_type)

#### Arguments

- `margin_profile_type`:

  Character; the margin profile type (required by the API), e.g.
  `"MARGIN_PROFILE_TYPE_RETAIL_INTRADAY_MARGIN_1"`.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `margin_window_type`, `end_time`, and the killswitch flags, or a
promise thereof.

------------------------------------------------------------------------

### `CoinbaseFutures$clone()`

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
