# File: R/utils_time.R
# Time conversion helpers. All Coinbase timestamps are handled in UTC and
# converted via lubridate.

#' Convert an ISO 8601 Timestamp to POSIXct
#'
#' @param x Character vector; ISO 8601 timestamps (e.g. `"2026-05-30T18:40:29.98Z"`).
#' @return POSIXct vector in UTC. Use [lubridate::with_tz()] to view elsewhere.
#'
#' @importFrom lubridate ymd_hms
#' @keywords internal
#' @noRd
iso_to_datetime <- function(x) {
  return(lubridate::ymd_hms(x, tz = "UTC"))
}

#' Convert an Epoch-Seconds Timestamp to POSIXct
#'
#' @param s Numeric vector; epoch seconds.
#' @return POSIXct vector in UTC.
#'
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
s_to_datetime <- function(s) {
  return(lubridate::as_datetime(as.numeric(s), tz = "UTC"))
}

#' Coerce a Datetime to Epoch Seconds
#'
#' Normalises a POSIXct, Date, or datetime-like value to UTC via
#' [lubridate::as_datetime()] and returns integer epoch seconds, the form the
#' Coinbase Exchange API expects for candle time bounds.
#'
#' @param x A POSIXct, Date, or value coercible by [lubridate::as_datetime()].
#' @return Integer; epoch seconds. `NULL` passes through as `NULL`.
#'
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
datetime_to_epoch <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  return(as.integer(as.numeric(lubridate::as_datetime(x, tz = "UTC"))))
}
