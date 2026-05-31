# Backfill Coinbase Trade History to CSV

Downloads deep tick history for one or more products and writes the
results incrementally to a CSV file. Supports resuming a partially
completed backfill by reading the existing file and continuing each
product from its last recorded trade. This is the foundation of the
data-collection pipeline: aggregate the resulting ticks with
[`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md)
for OHLCV at any timeframe.

## Usage

``` r
coinbase_backfill_trades(
  symbols,
  from = lubridate::now("UTC") - lubridate::dweeks(1),
  to = lubridate::now("UTC"),
  file,
  base_url = get_base_url(),
  exchange_base_url = get_exchange_base_url(),
  max_pages = Inf,
  sleep = 0.3,
  verbose = TRUE
)
```

## Arguments

- symbols:

  Character vector of product symbols (e.g. `c("BTC-USD", "ETH-USD")`).
  Must not be NULL or empty.

- from:

  POSIXct or numeric; start of the backfill window. Defaults to one week
  ago. Tick volume is large, so widen this deliberately.

- to:

  POSIXct or numeric; end of the window. Defaults to the current time.

- file:

  Character; path to the output CSV. Data is appended incrementally so
  progress survives interruption.

- base_url:

  Character; Advanced Trade API base URL.

- exchange_base_url:

  Character; Exchange API base URL.

- max_pages:

  Numeric; per-symbol cap on pages fetched. Default `Inf`.

- sleep:

  Numeric; seconds to sleep between symbols to respect rate limits.

- verbose:

  Logical; if `TRUE`, prints progress via
  [`rlang::inform()`](https://rlang.r-lib.org/reference/abort.html).

## Value

The file path (invisibly). If any symbols failed, a `"failures"`
attribute is attached: a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `symbol` and `error`.

## Details

Paging always begins at the most recent trade and walks backwards toward
`from`; for a fresh (non-resumed) run, leaving `from` as the default
pulls a bounded recent window rather than the product's entire history.

## Examples

``` r
if (FALSE) { # \dontrun{
coinbase_backfill_trades(
  symbols = c("BTC-USD", "ETH-USD"),
  from = lubridate::as_datetime("2026-05-01"),
  file = "trades.csv"
)
} # }
```
