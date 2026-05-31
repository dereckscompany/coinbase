#' Daily OHLCV Sample Data from Coinbase
#'
#' Historical daily candlestick (OHLCV) data for three major spot pairs
#' (`"BTC-USD"`, `"ETH-USD"`, `"SOL-USD"`) from the Coinbase Exchange API,
#' stacked into a single long table with a `symbol` column. Roughly 350 daily
#' candles per product, included for demonstration and examples. Produced with
#' [CoinbaseMarketData]'s `get_ohlcv()` method.
#'
#' @format A [data.table::data.table] with 1,050 rows and 7 columns:
#' - `symbol` (Character): Trading pair identifier, e.g. `"BTC-USD"`.
#' - `datetime` (POSIXct): Candle start time in UTC.
#' - `open` (Numeric): Opening price.
#' - `high` (Numeric): Highest price during the interval.
#' - `low` (Numeric): Lowest price during the interval.
#' - `close` (Numeric): Closing price.
#' - `volume` (Numeric): Trading volume in base currency.
#'
#' @source Coinbase Exchange API via `CoinbaseMarketData$get_ohlcv()`
#' @examples
#' data(coinbase_ohlcv)
#' head(coinbase_ohlcv)
"coinbase_ohlcv"
