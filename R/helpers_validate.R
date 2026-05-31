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
    length(order_configuration) == 1L &&
    !is.null(nms) &&
    nzchar(nms[1])
  if (!ok) {
    rlang::abort(paste0(
      "`order_configuration` must be a single-key named list, e.g. ",
      "list(market_market_ioc = list(quote_size = \"10\"))."
    ))
  }
  return(invisible(TRUE))
}
