# File: R/helpers_parse.R
# Response parsing and data.table construction helpers.

#' Convert camelCase Names to snake_case
#'
#' Converts response field names to R's snake_case convention. Coinbase fields
#' are predominantly snake_case already, so this is largely a pass-through; it
#' exists to guarantee the convention holds for any camelCase outliers.
#'
#' @param names Character vector; names to convert.
#' @return Character vector; converted snake_case names.
#'
#' @keywords internal
#' @noRd
to_snake_case <- function(names) {
  out <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", names)
  out <- gsub("([A-Z])([A-Z][a-z])", "\\1_\\2", out)
  out <- tolower(out)
  return(out)
}

#' Convert a Named List to a Single-Row data.table
#'
#' Converts a flat named list (from a Coinbase JSON object) into a single-row
#' [data.table::data.table]. NULL values become NA. Nested lists of length >= 1
#' are wrapped so data.table stores them as a single list-column entry rather
#' than recycling rows; callers that must avoid list columns flatten such fields
#' explicitly before calling this.
#'
#' @param x A named list.
#' @return A single-row [data.table::data.table] with snake_case column names.
#'
#' @keywords internal
#' @noRd
as_dt_row <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(data.table::data.table()[])
  }
  x <- lapply(x, function(val) {
    if (is.null(val)) {
      return(NA)
    }
    if (is.list(val) && length(val) == 0) {
      return(NA)
    }
    if (is.list(val) && length(val) >= 1) {
      return(list(val))
    }
    return(val)
  })
  dt <- data.table::as.data.table(x)
  data.table::setnames(dt, to_snake_case(names(dt)))
  return(dt[])
}

#' Convert a List of Named Lists to a data.table
#'
#' Row-binds a list whose elements are named lists (a JSON array of objects)
#' into a [data.table::data.table] with snake_case columns.
#'
#' @param items A list of named lists, or NULL.
#' @return A [data.table::data.table]; empty if `items` is NULL or empty.
#'
#' @keywords internal
#' @noRd
as_dt_list <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  dt <- data.table::rbindlist(lapply(items, as_dt_row), fill = TRUE)
  return(dt[])
}

#' Parse Coinbase Exchange Candles into an OHLCV data.table
#'
#' The Exchange API returns each candle as the array
#' `[time, low, high, open, close, volume]` (time in epoch seconds), newest
#' first. This reorders to the canonical OHLCV layout and sorts ascending.
#'
#' @param data A list of candle arrays, or NULL.
#' @return A [data.table::data.table] with columns `datetime`, `open`, `high`,
#'   `low`, `close`, `volume`. Empty if `data` is NULL or empty.
#'
#' @keywords internal
#' @noRd
parse_candles <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  dt <- data.table::data.table(
    datetime = s_to_datetime(vapply(data, function(c) as.numeric(c[[1L]]), numeric(1))),
    open = vapply(data, function(c) as.numeric(c[[4L]]), numeric(1)),
    high = vapply(data, function(c) as.numeric(c[[3L]]), numeric(1)),
    low = vapply(data, function(c) as.numeric(c[[2L]]), numeric(1)),
    close = vapply(data, function(c) as.numeric(c[[5L]]), numeric(1)),
    volume = vapply(data, function(c) as.numeric(c[[6L]]), numeric(1))
  )
  data.table::setorder(dt, datetime)
  return(dt[])
}

#' Parse Coinbase Exchange Trades into a data.table
#'
#' @param data A list of trade objects (`trade_id`, `side`, `size`, `price`,
#'   `time`), or NULL.
#' @return A [data.table::data.table] with columns `trade_id`, `side`, `price`,
#'   `size`, `time`. Empty if `data` is NULL or empty.
#'
#' @keywords internal
#' @noRd
parse_trades <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  dt <- data.table::data.table(
    trade_id = vapply(data, function(t) as.numeric(t$trade_id), numeric(1)),
    side = vapply(data, function(t) as.character(t$side), character(1)),
    price = vapply(data, function(t) as.numeric(t$price), numeric(1)),
    size = vapply(data, function(t) as.numeric(t$size), numeric(1)),
    time = iso_to_datetime(vapply(data, function(t) as.character(t$time), character(1)))
  )
  return(dt[])
}

#' Parse a Coinbase Exchange Order Book into a long data.table
#'
#' Flattens the `bids`/`asks` arrays (each entry `[price, size, num_orders]`)
#' into a single long table with a `side` column, avoiding any list columns.
#'
#' @param data A list with `bids` and `asks`, or NULL.
#' @return A [data.table::data.table] with columns `side`, `price`, `size`,
#'   `num_orders`. Empty if `data` is NULL or empty.
#'
#' @keywords internal
#' @noRd
parse_orderbook <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  one_side <- function(levels, side) {
    if (is.null(levels) || length(levels) == 0) {
      return(data.table::data.table()[])
    }
    return(data.table::data.table(
      side = side,
      price = vapply(levels, function(l) as.numeric(l[[1L]]), numeric(1)),
      size = vapply(levels, function(l) as.numeric(l[[2L]]), numeric(1)),
      num_orders = vapply(levels, function(l) as.numeric(l[[3L]]), numeric(1))
    ))
  }
  dt <- data.table::rbindlist(
    list(one_side(data$bids, "bid"), one_side(data$asks, "ask")),
    fill = TRUE
  )
  return(dt[])
}
