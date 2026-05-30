# File: R/helpers_aggregate.R
# Pure, instance-free helpers for transforming tick data and validating symbols.

#' Verify a Coinbase Product Symbol
#'
#' Checks whether a symbol matches Coinbase's `"BASE-QUOTE"` format
#' (e.g. `"BTC-USD"`): alphanumeric segments separated by a single dash.
#'
#' @param product_id Character string; the symbol to verify.
#' @return Logical; `TRUE` if valid, `FALSE` otherwise.
#'
#' @examples
#' verify_symbol("BTC-USD") # TRUE
#' verify_symbol("BTCUSD") # FALSE
#' @export
verify_symbol <- function(product_id) {
  return(grepl("^[A-Za-z0-9]+-[A-Za-z0-9]+$", product_id))
}

#' Aggregate Tick Trades into OHLCV Bars
#'
#' Converts a table of raw tick trades (as returned by
#' `CoinbaseMarketData$get_trades()` or the backfill) into OHLCV candles at an
#' arbitrary interval. This is the deep-history path: Coinbase's candle endpoint
#' is shallow, so complete OHLCV at any timeframe is built from ticks.
#'
#' Open/close are the first/last trade price within each bar (by time, with
#' `trade_id` as a tiebreaker when present); high/low are the extremes; volume is
#' the summed trade size. Empty intervals produce no row.
#'
#' @param trades A [data.table::data.table] of trades with at least `time`
#'   (POSIXct), `price` (numeric), and `size` (numeric) columns; `trade_id`
#'   (numeric) is used as a tiebreaker if present.
#' @param interval Numeric; bar width in seconds (e.g. `60` for 1-minute bars).
#' @return A [data.table::data.table] with columns `datetime`, `open`, `high`,
#'   `low`, `close`, `volume`, sorted ascending by `datetime`. `datetime` is the
#'   floored start of each bar. Empty if `trades` is empty.
#'
#' @examples
#' \dontrun{
#' market <- CoinbaseMarketData$new()
#' ticks <- market$get_trades("BTC-USD", limit = 1000)
#' bars <- trades_to_ohlcv(ticks, interval = 60)
#' }
#' @import data.table
#' @export
trades_to_ohlcv <- function(trades, interval = 60) {
  assert::assert_data_table(trades)
  assert::assert_scalar_positive(interval)

  if (nrow(trades) == 0L) {
    return(data.table::data.table()[])
  }

  assert::assert_column_types(trades, "POSIXct", "time")
  assert::assert_column_types(trades, "numeric", c("price", "size"))

  dt <- data.table::copy(trades)

  # Stable chronological order; trade_id breaks ties within identical timestamps.
  if ("trade_id" %in% names(dt)) {
    data.table::setorder(dt, time, trade_id)
  } else {
    data.table::setorder(dt, time)
  }

  # Floor each trade's epoch-seconds to its bar start.
  epoch <- as.numeric(dt$time)
  dt[, datetime := s_to_datetime(floor(epoch / interval) * interval)]

  bars <- dt[, list(
    open = price[1L],
    high = max(price),
    low = min(price),
    close = price[.N],
    volume = sum(size)
  ), by = datetime]

  data.table::setorder(bars, datetime)
  return(bars[])
}
