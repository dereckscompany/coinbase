# File: R/utils_time.R
# Time conversion helpers. All Coinbase timestamps are handled in UTC and
# converted via lubridate.

#' Convert an ISO 8601 Timestamp to POSIXct
#'
#' @param x (character | NA) ISO 8601 timestamps (e.g. `"2026-05-30T18:40:29.98Z"`).
#' @return (POSIXct | NA) vector in UTC. Use [lubridate::with_tz()] to view
#'   elsewhere.
#'
#' @importFrom lubridate ymd_hms
#' @keywords internal
#' @noRd
iso_to_datetime <- function(x) {
  assert_args_iso_to_datetime(x)
  return(assert_return_iso_to_datetime(lubridate::ymd_hms(x, tz = "UTC")))
}

#' Convert an Epoch-Seconds Timestamp to POSIXct
#'
#' @param s (numeric | NA) epoch seconds.
#' @return (POSIXct | NA) vector in UTC.
#'
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
s_to_datetime <- function(s) {
  assert_args_s_to_datetime(s)
  return(assert_return_s_to_datetime(lubridate::as_datetime(as.numeric(s), tz = "UTC")))
}

#' Coerce a Datetime to Epoch Seconds
#'
#' Normalises a POSIXct, Date, or datetime-like value to UTC via
#' [lubridate::as_datetime()] and returns integer epoch seconds, the form the
#' Coinbase Exchange API expects for candle time bounds.
#'
#' @param x (any | NULL) a POSIXct, Date, or value coercible by
#'   [lubridate::as_datetime()].
#' @return (numeric | NULL) whole-number epoch seconds. `NULL` passes through as
#'   `NULL`.
#'
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
datetime_to_epoch <- function(x) {
  assert_args_datetime_to_epoch(x)
  if (is.null(x)) {
    return(assert_return_datetime_to_epoch(NULL))
  }
  # Keep this a double, not as.integer(): epoch seconds beyond 2038-01-19 exceed
  # the 32-bit integer range and would silently become NA. httr2 serialises a
  # whole-number double cleanly (no scientific notation) in the query string.
  return(assert_return_datetime_to_epoch(floor(as.numeric(lubridate::as_datetime(x, tz = "UTC")))))
}

#' Convert a Coinbase Timestamp to POSIXct
#'
#' Coinbase returns times in two forms: ISO 8601 strings (most endpoints) and
#' epoch seconds (the Exchange candle bounds). This converts either form to a
#' POSIXct in UTC.
#'
#' @param time_value (character | numeric) ISO 8601 timestamp(s), or numeric
#'   epoch seconds.
#' @param unit (scalar<character in c("iso", "s")>) the input form: `"iso"` (ISO
#'   8601 string, default) or `"s"` (epoch seconds).
#' @return (POSIXct | NA) vector in UTC.
#'
#' @examples
#' \dontrun{
#' time_convert_from_coinbase("2026-05-31T18:40:29Z")
#' time_convert_from_coinbase(1780203360, unit = "s")
#' }
#'
#' @export
time_convert_from_coinbase <- function(time_value, unit = c("iso", "s")) {
  unit <- match.arg(unit)
  assert_args_time_convert_from_coinbase(time_value, unit)
  result <- switch(
    unit,
    iso = iso_to_datetime(time_value),
    s = s_to_datetime(time_value)
  )
  return(assert_return_time_convert_from_coinbase(result))
}

#' Convert a POSIXct to a Coinbase Timestamp
#'
#' Formats a POSIXct as the timestamp form Coinbase expects: an ISO 8601 string
#' (`"iso"`, default) or whole-number epoch seconds (`"s"`, used for the Exchange
#' candle bounds).
#'
#' @param datetime (POSIXct) object(s) to convert.
#' @param unit (scalar<character in c("iso", "s")>) the output form: `"iso"`
#'   (default) or `"s"`.
#' @return (character | numeric) an ISO 8601 timestamp (`"iso"`) or numeric epoch
#'   seconds (`"s"`).
#'
#' @examples
#' \dontrun{
#' dt <- lubridate::as_datetime("2026-05-31 18:40:29", tz = "UTC")
#' time_convert_to_coinbase(dt)            # "2026-05-31T18:40:29Z"
#' time_convert_to_coinbase(dt, unit = "s") # 1780252829
#' }
#'
#' @export
time_convert_to_coinbase <- function(datetime, unit = c("iso", "s")) {
  unit <- match.arg(unit)
  assert_args_time_convert_to_coinbase(datetime, unit)
  result <- switch(
    unit,
    iso = format(datetime, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    s = datetime_to_epoch(datetime)
  )
  return(assert_return_time_convert_to_coinbase(result))
}
