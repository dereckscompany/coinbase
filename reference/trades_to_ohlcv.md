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

  (class\<data.table\>) trades with at least `timestamp` (POSIXct),
  `price` (numeric), and `size` (numeric) columns; `trade_id` (numeric)
  is used as a tiebreaker if present.

- interval:

  (scalar\<numeric in \]0, Inf\[\>) bar width in seconds (e.g. `60` for
  1-minute bars).

## Value

(Ohlcv) one row per OHLCV bar, sorted ascending by `datetime`;
`datetime` is the floored start of each bar. Empty if `trades` is empty.

## Details

Each trade is assigned to a bar by **flooring** its timestamp to the
nearest lower multiple of `interval` seconds, so a bar's `datetime` is
its inclusive start (left-closed, right-open) and sub-`interval`
precision is discarded. Open/close are the first/last trade price within
each bar (by time, with `trade_id` as a tiebreaker when present);
high/low are the extremes; volume is the summed trade size. Empty
intervals produce no row.

## Examples

``` r
if (FALSE) { # \dontrun{
market <- CoinbaseMarketData$new()
ticks <- market$get_trades("BTC-USD", limit = 1000)
bars <- trades_to_ohlcv(ticks, interval = 60)
} # }
```
