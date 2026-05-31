# Aggregate Tick Trades into OHLCV Bars

Converts a table of raw tick trades (as returned by
`CoinbaseMarketData$get_trades()` or the backfill) into OHLCV candles at
an arbitrary interval. This is the deep-history path: Coinbase's candle
endpoint is shallow, so complete OHLCV at any timeframe is built from
ticks.

## Usage

``` r
trades_to_ohlcv(trades, interval = 60)
```

## Arguments

- trades:

  A
  [data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
  of trades with at least `time` (POSIXct), `price` (numeric), and
  `size` (numeric) columns; `trade_id` (numeric) is used as a tiebreaker
  if present.

- interval:

  Numeric; bar width in seconds (e.g. `60` for 1-minute bars).

## Value

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `datetime`, `open`, `high`, `low`, `close`, `volume`,
sorted ascending by `datetime`. `datetime` is the floored start of each
bar. Empty if `trades` is empty.

## Details

Open/close are the first/last trade price within each bar (by time, with
`trade_id` as a tiebreaker when present); high/low are the extremes;
volume is the summed trade size. Empty intervals produce no row.

## Examples

``` r
if (FALSE) { # \dontrun{
market <- CoinbaseMarketData$new()
ticks <- market$get_trades("BTC-USD", limit = 1000)
bars <- trades_to_ohlcv(ticks, interval = 60)
} # }
```
