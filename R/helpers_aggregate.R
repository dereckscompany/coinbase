# File: R/helpers_aggregate.R
# Pure, instance-free helpers for transforming tick data and validating symbols.

#' Verify a Coinbase Product Symbol
#'
#' Checks whether a symbol is a dash-separated alphanumeric product ID. This
#' covers spot pairs (`"BTC-USD"`) as well as the multi-segment expiring-futures
#' IDs CFM uses (`"BIT-28FEB25-CDE"`) — anything with at least two segments
#' joined by single dashes.
#'
#' @param product_id (scalar<character>) the symbol to verify.
#' @return (scalar<logical>) `TRUE` if valid, `FALSE` otherwise.
#'
#' @examples
#' verify_symbol("BTC-USD") # TRUE
#' verify_symbol("BIT-28FEB25-CDE") # TRUE
#' verify_symbol("BTCUSD") # FALSE
#' @export
verify_symbol <- function(product_id) {
  assert_args_verify_symbol(product_id)
  return(assert_return_verify_symbol(grepl("^[A-Za-z0-9]+(-[A-Za-z0-9]+)+$", product_id)))
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
#' @param trades (class<data.table>) trades with at least `time` (POSIXct),
#'   `price` (numeric), and `size` (numeric) columns; `trade_id` (numeric) is
#'   used as a tiebreaker if present.
#' @param interval (scalar<numeric in ]0, Inf[>) bar width in seconds (e.g. `60`
#'   for 1-minute bars).
#' @return (class<data.table>) columns `datetime`, `open`, `high`, `low`,
#'   `close`, `volume`, sorted ascending by `datetime`. `datetime` is the floored
#'   start of each bar. Empty if `trades` is empty.
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
  assert_args_trades_to_ohlcv(trades, interval)

  if (nrow(trades) == 0L) {
    return(assert_return_trades_to_ohlcv(data.table::data.table()[]))
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

  bars <- dt[,
    list(
      open = price[1L],
      high = max(price),
      low = min(price),
      close = price[.N],
      volume = sum(size)
    ),
    by = datetime
  ]

  data.table::setorder(bars, datetime)
  return(assert_return_trades_to_ohlcv(bars[]))
}
