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
  if (length(v) != 1L || is.na(v) || v <= 0) {
    rlang::abort(sprintf("`%s` must be a single positive number.", name))
  }
  return(format(v, scientific = FALSE, trim = TRUE))
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
