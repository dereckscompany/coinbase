# Backfill Coinbase OHLCV Candles to CSV

Downloads historical price candles (open/high/low/close/volume) for one
or more products across one or more timeframes and writes them to a CSV
file, one row per candle. Coinbase only returns about 300 candles per
request, so this walks the whole date range for you, page by page, and
appends as it goes. Re-running it against the same file resumes from the
last saved candle, so an interrupted run is safe to just restart. This
is the Coinbase sibling of
[`coinbase_backfill_trades()`](https://dereckscompany.github.io/coinbase/reference/coinbase_backfill_trades.md)
and mirrors the kucoin/binance `*_backfill_klines()` contract.

## Usage

``` r
coinbase_backfill_klines(
  symbols,
  timeframes = "1day",
  from = lubridate::now("UTC") - lubridate::ddays(365),
  to = lubridate::now("UTC"),
  file,
  base_url = get_base_url(),
  exchange_base_url = get_exchange_base_url(),
  max_bars = 300L,
  sleep = 0.3,
  verbose = TRUE
)
```

## Arguments

- symbols:

  (character) product symbols (e.g. `c("BTC-USD", "ETH-USD")`). Must not
  be NULL or empty.

- timeframes:

  (character) candle timeframes; the Coinbase granularities `"1min"`,
  `"5min"`, `"15min"`, `"1hour"`, `"6hour"`, `"1day"`. Default `"1day"`.

- from:

  (POSIXct \| numeric) start of the backfill window. Defaults to one
  year ago.

- to:

  (POSIXct \| numeric) end of the backfill window. Defaults to the
  current time.

- file:

  (scalar\<character\>) path to the output CSV. Data is appended
  incrementally so progress survives interruption.

- base_url:

  (scalar\<character\>) Advanced Trade API base URL.

- exchange_base_url:

  (scalar\<character\>) Exchange API base URL (the host that serves
  `/candles`).

- max_bars:

  (scalar\<count in \[1, Inf\[\>) candles per request window (the
  endpoint cap). Default 300.

- sleep:

  (scalar\<numeric in \[0, Inf\[\>) seconds to sleep between request
  windows and between combinations to respect rate limits.

- verbose:

  (scalar\<logical\>) if `TRUE`, prints progress via
  [`rlang::inform()`](https://rlang.r-lib.org/reference/abort.html).

## Value

(scalar\<character\>) the file path (invisibly). The written CSV has
columns `datetime`, `open`, `high`, `low`, `close`, `volume`, `symbol`,
`timeframe`.

## Details

**Window mechanics.** The Coinbase Exchange `/candles` endpoint caps a
single response at ~300 bars, so each `(symbol, timeframe)` range is
tiled into contiguous windows of at most `max_bars` bars driven over
`CoinbaseMarketData$get_ohlcv()`. Windows are inclusive of both ends and
the next starts one step past the previous end, so they tile the range
without a boundary gap. Epoch-second arithmetic is done in double, never
32-bit integer, so day-granularity spans past 2038 cannot silently
overflow.

**Resume semantics.** When `file` already holds rows for a
`(symbol, timeframe)`, the fetch restarts *inclusively* from that
combination's last stored candle and the boundary duplicate is collapsed
— only strictly-newer candles are appended — so a restart can neither
strand a gap nor repeat a row. A combination whose last stored candle
already reaches `to` is skipped as up to date.

**Dedup and closed candles.** Pages are unioned and deduplicated by
`datetime`, sorted ascending. Only *closed* candles are written: the bar
still forming at the live edge (open time `t` where `t + step > now`) is
dropped so a half-built candle is never persisted (a resume would
otherwise advance past it and never refresh it).

**Failures.** Each failed `(symbol, timeframe)` combination raises one
[`rlang::warn()`](https://rlang.r-lib.org/reference/abort.html), and
after the loop a final summary warning lists the count and the affected
combinations (the kucoin/binance convention downstream failure ledgers
key on). No failure data is hidden on the return value.

## Examples

``` r
if (FALSE) { # \dontrun{
coinbase_backfill_klines(
  symbols = c("BTC-USD", "ETH-USD"),
  timeframes = c("1day", "1hour"),
  from = lubridate::as_datetime("2020-01-01"),
  file = "coinbase_klines.csv"
)
} # }
```
