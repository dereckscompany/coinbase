# File: R/helpers_validate.R
# Internal input validators shared across the client classes. These abort with
# an actionable message on invalid input, before any request is sent.

#' Validate a Product Symbol
#'
#' @param product_id Character; must be a scalar in `"BASE-QUOTE"` form.
#' @return Invisibly `TRUE`; aborts otherwise.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_symbol <- function(product_id) {
  assert::assert_scalar_character(product_id)
  if (!verify_symbol(product_id)) {
    rlang::abort(paste0(
      "Invalid product_id '",
      product_id,
      "'. Expected BASE-QUOTE form, e.g. \"BTC-USD\"."
    ))
  }
  return(invisible(TRUE))
}

#' Validate an Order Side
#'
#' @param side Character; must be `"BUY"` or `"SELL"` (case-insensitive).
#' @return The upper-cased side; aborts on anything else.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_side <- function(side) {
  assert::assert_scalar_character(side)
  up <- toupper(side)
  if (!up %in% c("BUY", "SELL")) {
    rlang::abort(paste0("Invalid side '", side, "'. Expected \"BUY\" or \"SELL\"."))
  }
  return(up)
}

#' Coerce a Value to a Positive Decimal String
#'
#' Validates that `x` is a single positive number and returns it as a plain
#' (non-scientific) decimal string, the form the Coinbase API expects for
#' prices, sizes, and amounts. Aborts with a clean message on anything else.
#'
#' @param x A scalar numeric or numeric-like string.
#' @param name Character; the parameter name, for the error message.
#' @return Character; the value as a non-scientific decimal string.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
coerce_positive_string <- function(x, name) {
  v <- suppressWarnings(as.numeric(x))
  # is.finite rejects NA, NaN, Inf, -Inf, and overflow (e.g. "1e999" -> Inf).
  if (length(v) != 1L || !is.finite(v) || v <= 0) {
    rlang::abort(sprintf("`%s` must be a single positive finite number.", name))
  }
  # Only a canonical plain-decimal character input is returned VERBATIM (so the
  # exact value the user typed is sent unchanged, preserving full precision).
  # Anything else as.numeric() tolerates -- hex ("0x10"), a leading sign ("+5"),
  # a leading/trailing dot (".5", "1."), or scientific notation -- is routed
  # through format() so the validated NUMBER (not the raw token) is transmitted.
  if (is.character(x) && grepl("^[0-9]+(\\.[0-9]+)?$", trimws(x))) {
    return(trimws(x))
  }
  return(format(v, scientific = FALSE, trim = TRUE, digits = 15))
}

#' Validate an Order Configuration
#'
#' @param order_configuration A single-key named list naming the detailed order
#'   type, e.g. `list(market_market_ioc = list(quote_size = "10"))`.
#' @return Invisibly `TRUE`; aborts otherwise.
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
  return(invisible(TRUE))
}

#' Stringify Numeric Fields in an Order Configuration
#'
#' Coinbase expects order sizes/prices as strings. If a caller passes numerics
#' inside `order_configuration` (e.g. `base_size = 0.00000001`), `jsonlite`
#' would serialise them with only 4 decimals / scientific notation, silently
#' corrupting the value. This converts every numeric leaf of the inner config to
#' a full-precision, non-scientific decimal string; logicals (e.g. `post_only`)
#' and existing strings are left untouched.
#'
#' @param order_configuration A validated single-key order configuration.
#' @return The same structure with numeric leaves converted to strings.
#'
#' @keywords internal
#' @noRd
stringify_order_config <- function(order_configuration) {
  key <- names(order_configuration)[1]
  inner <- order_configuration[[key]]
  inner <- lapply(inner, function(val) {
    if (is.numeric(val)) {
      return(format(val, scientific = FALSE, trim = TRUE, digits = 15))
    }
    return(val)
  })
  out <- list()
  out[[key]] <- inner
  return(out)
}
