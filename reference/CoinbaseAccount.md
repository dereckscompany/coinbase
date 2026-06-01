# CoinbaseAccount: Account, Balance, and Fee Information

Retrieves authenticated account data from the Coinbase Advanced Trade
API: trading accounts (balances), the transaction/fee summary,
portfolios, and the API key's permissions. All endpoints require
credentials.

Inherits from
[CoinbaseBase](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md).
All methods support both synchronous and asynchronous execution
depending on the `async` argument at construction.

### Pagination

`get_accounts()` walks Coinbase's body-cursor pagination (`cursor` /
`has_next`) to return all accounts across pages.

### Endpoints Covered

|                         |                                           |      |
|-------------------------|-------------------------------------------|------|
| Method                  | Endpoint                                  | Auth |
| get_accounts            | GET /api/v3/brokerage/accounts            | Yes  |
| get_account             | GET /api/v3/brokerage/accounts/{uuid}     | Yes  |
| get_fees                | GET /api/v3/brokerage/transaction_summary | Yes  |
| get_portfolios          | GET /api/v3/brokerage/portfolios          | Yes  |
| get_portfolio_breakdown | GET /api/v3/brokerage/portfolios/{uuid}   | Yes  |
| get_portfolio_summary   | GET /api/v3/brokerage/portfolios/{uuid}   | Yes  |
| get_key_permissions     | GET /api/v3/brokerage/key_permissions     | Yes  |

## Super class

[`CoinbaseBase`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md)
-\> `CoinbaseAccount`

## Methods

### Public methods

- [`CoinbaseAccount$get_accounts()`](#method-CoinbaseAccount-get_accounts)

- [`CoinbaseAccount$get_account()`](#method-CoinbaseAccount-get_account)

- [`CoinbaseAccount$get_fees()`](#method-CoinbaseAccount-get_fees)

- [`CoinbaseAccount$get_portfolios()`](#method-CoinbaseAccount-get_portfolios)

- [`CoinbaseAccount$get_portfolio_breakdown()`](#method-CoinbaseAccount-get_portfolio_breakdown)

- [`CoinbaseAccount$get_portfolio_summary()`](#method-CoinbaseAccount-get_portfolio_summary)

- [`CoinbaseAccount$get_key_permissions()`](#method-CoinbaseAccount-get_key_permissions)

- [`CoinbaseAccount$clone()`](#method-CoinbaseAccount-clone)

Inherited methods

- [`CoinbaseBase$initialize()`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.html#method-initialize)

------------------------------------------------------------------------

### `CoinbaseAccount$get_accounts()`

Retrieve all trading accounts (balances), paginating over the cursor
until exhausted.

#### Usage

    CoinbaseAccount$get_accounts(limit = NULL, max_pages = Inf)

#### Arguments

- `limit`:

  Integer or NULL; page size. Optional.

- `max_pages`:

  Numeric; cap on pages fetched. Default `Inf`.

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of accounts, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseAccount$get_account()`

Retrieve a single account by its UUID.

#### Usage

    CoinbaseAccount$get_account(account_uuid)

#### Arguments

- `account_uuid`:

  Character; the account UUID.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseAccount$get_fees()`

Retrieve the transaction/fee summary, including the current maker/taker
fee tier.

#### Usage

    CoinbaseAccount$get_fees(product_type = NULL)

#### Arguments

- `product_type`:

  Character or NULL; `"SPOT"` or `"FUTURE"` to scope the summary.
  Optional.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseAccount$get_portfolios()`

Retrieve the user's portfolios.

#### Usage

    CoinbaseAccount$get_portfolios()

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of portfolios, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseAccount$get_portfolio_breakdown()`

Retrieve a single portfolio's positions: its spot, futures, and
perpetual holdings stacked into one `data.table`, one row per holding,
tagged by a `position_type` column. The concepts shared across types are
normalised to common columns (`entry_price`, `mark_price`, `side`,
`unrealized_pnl`); the rest keep their API names. For the portfolio's
aggregate balance totals, use `get_portfolio_summary()` (it reads the
same endpoint).

#### Usage

    CoinbaseAccount$get_portfolio_breakdown(portfolio_uuid, currency = NULL)

#### Arguments

- `portfolio_uuid`:

  Character; the portfolio UUID (from `get_portfolios()`).

- `currency`:

  Character or NULL; quote currency for fiat values. Optional.

#### Returns

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of positions, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseAccount$get_portfolio_summary()`

Retrieve a single portfolio's aggregate balance totals (total balance,
futures/crypto/cash-equivalent balances, and futures/perp unrealized
PnL). The positions companion is `get_portfolio_breakdown()`; both read
the same endpoint.

#### Usage

    CoinbaseAccount$get_portfolio_summary(portfolio_uuid, currency = NULL)

#### Arguments

- `portfolio_uuid`:

  Character; the portfolio UUID (from `get_portfolios()`).

- `currency`:

  Character or NULL; quote currency for fiat values. Optional.

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
of totals, or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseAccount$get_key_permissions()`

Retrieve the calling API key's permissions.

#### Usage

    CoinbaseAccount$get_key_permissions()

#### Returns

A single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
or a promise thereof.

------------------------------------------------------------------------

### `CoinbaseAccount$clone()`

The objects of this class are cloneable with this method.

#### Usage

    CoinbaseAccount$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
account <- CoinbaseAccount$new()
account$get_accounts()
account$get_fees()
} # }
```
