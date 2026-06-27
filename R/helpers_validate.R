# File: R/helpers_validate.R
# Internal input validators shared across the client classes. These abort with
# an actionable message on invalid input, before any request is sent.

#' Validate a Product Symbol
#'
#' @param product_id (scalar<character>) must be a scalar in `"BASE-QUOTE"` form.
#' @return (scalar<logical>) invisibly `TRUE`; aborts otherwise.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_symbol <- function(product_id) {
  assert_args_validate_symbol(product_id)
  if (!verify_symbol(product_id)) {
    rlang::abort(paste0(
      "Invalid product_id '",
      product_id,
      "'. Expected BASE-QUOTE form, e.g. \"BTC-USD\"."
    ))
  }
  return(invisible(assert_return_validate_symbol(TRUE)))
}

#' Validate an Order Side
#'
#' @param side (scalar<character>) must be `"BUY"` or `"SELL"` (case-insensitive).
#' @return (scalar<character in c("BUY", "SELL")>) the upper-cased side; aborts on
#'   anything else.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_side <- function(side) {
  assert_args_validate_side(side)
  up <- toupper(side)
  if (!up %in% c("BUY", "SELL")) {
    rlang::abort(paste0("Invalid side '", side, "'. Expected \"BUY\" or \"SELL\"."))
  }
  return(assert_return_validate_side(up))
}

#' Format a Number as a Locale-Independent Non-Scientific Decimal String
#'
#' `format()`/`formatC()` honour `getOption("OutDec")`, so under a comma-decimal
#' locale a price would serialise as e.g. `"50000,5"` and corrupt the order.
#' This forces a `.` decimal mark and full (15-digit) non-scientific precision.
#'
#' @param v (scalar<numeric in ]-Inf, Inf[>) a finite numeric scalar.
#' @return (scalar<character>) the value as a plain decimal string with a `.`
#'   separator.
#'
#' @keywords internal
#' @noRd
format_decimal <- function(v) {
  assert_args_format_decimal(v)
  old <- options(OutDec = ".")
  on.exit(options(old), add = TRUE)
  return(assert_return_format_decimal(format(v, scientific = FALSE, trim = TRUE, digits = 15)))
}

#' Coerce a Value to a Positive Decimal String
#'
#' Validates that `x` is a single positive, finite number and returns it as a
#' plain (non-scientific, `.`-separated) decimal string, the form the Coinbase
#' API expects for prices, sizes, and amounts. Aborts on anything else.
#'
#' @param x (scalar<numeric> | scalar<character>) a scalar numeric or
#'   numeric-like string.
#' @param name (scalar<character>) the parameter name, for the error message.
#' @return (scalar<character>) the value as a non-scientific decimal string.
#' @noassert x
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
coerce_positive_string <- function(x, name) {
  assert_args_coerce_positive_string(name)
  v <- suppressWarnings(as.numeric(x))
  # is.finite rejects NA, NaN, Inf, -Inf, and overflow (e.g. "1e999" -> Inf).
  if (length(v) != 1L || !is.finite(v) || v <= 0) {
    rlang::abort(sprintf("`%s` must be a single positive finite number.", name))
  }
  # Only a canonical plain-decimal character input is returned VERBATIM (so the
  # exact value the user typed is sent unchanged, preserving full precision).
  # Anything else as.numeric() tolerates -- hex ("0x10"), a leading sign ("+5"),
  # a leading/trailing dot (".5", "1."), or scientific notation -- is routed
  # through the validated NUMBER (not the raw token).
  if (is.character(x) && grepl("^[0-9]+(\\.[0-9]+)?$", trimws(x))) {
    return(assert_return_coerce_positive_string(trimws(x)))
  }
  return(assert_return_coerce_positive_string(format_decimal(v)))
}

#' Validate an Order Configuration
#'
#' @param order_configuration (list) a single-key named list naming the detailed
#'   order type, e.g. `list(market_market_ioc = list(quote_size = "10"))`.
#' @return (scalar<logical>) invisibly `TRUE`; aborts otherwise.
#' @noassert order_configuration
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_order_config <- function(order_configuration) {
  nms <- names(order_configuration)
  ok <- is.list(order_configuration) &&
    !is.data.frame(order_configuration) &&
    length(order_configuration) == 1L &&
    !is.null(nms) &&
    !is.na(nms[1]) &&
    nzchar(nms[1]) &&
    is.list(order_configuration[[1]])
  if (!ok) {
    rlang::abort(paste0(
      "`order_configuration` must be a single-key named list, e.g. ",
      "list(market_market_ioc = list(quote_size = \"10\"))."
    ))
  }
  return(invisible(assert_return_validate_order_config(TRUE)))
}

#' Validate and Stringify the Money Fields of an Order Configuration
#'
#' Coinbase expects order sizes/prices as strings. The money leaves
#' (`base_size`, `quote_size`, `limit_price`, `stop_price`, `stop_trigger_price`)
#' are routed through [coerce_positive_string()] so they are both VALIDATED
#' (positive, finite -- never `Inf`/`NaN`/negative) and serialised at full,
#' locale-independent, non-scientific precision. Non-money leaves (`post_only`,
#' `end_time`, `stop_direction`, `leverage`, ...) are left untouched.
#'
#' @param order_configuration (list) a structurally-validated single-key order
#'   config.
#' @return (list) the same structure with money leaves validated and stringified.
#'
#' @keywords internal
#' @noRd
stringify_order_config <- function(order_configuration) {
  assert_args_stringify_order_config(order_configuration)
  money_keys <- c("base_size", "quote_size", "limit_price", "stop_price", "stop_trigger_price")
  key <- names(order_configuration)[1]
  inner <- order_configuration[[key]]
  # Drop NULL leaves so they are omitted rather than serialised as JSON null;
  # the reference SDK likewise filters nested NULLs before sending.
  inner <- inner[!vapply(inner, is.null, logical(1))]
  inner_names <- names(inner)
  inner <- lapply(seq_along(inner), function(i) {
    nm <- inner_names[i]
    val <- inner[[i]]
    if (!is.null(nm) && nm %in% money_keys) {
      return(coerce_positive_string(val, nm))
    }
    return(val)
  })
  names(inner) <- inner_names
  out <- list()
  out[[key]] <- inner
  return(assert_return_stringify_order_config(out))
}
