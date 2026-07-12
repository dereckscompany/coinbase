# File: R/conditions.R
# Coinbase's typed API-error condition. Coinbase signals failure with HTTP status
# codes (there is no 200-envelope error surface), so a single raiser sits at the
# `parse_coinbase_response()` funnel and layers Coinbase's own class family IN
# FRONT of connectcore's, per the recipe in `?connectcore_conditions`. A caller
# can then catch `coinbase_api_error` (any Coinbase HTTP failure),
# `connectcore_api_error` (any HTTP failure fleet-wide), or `connectcore_error`
# (any transport failure) — reading `e$status` / `e$url` / `e$body_snippet`
# instead of grepping the message text.
#
# Backward compatibility is a hard contract: the message string is byte-identical
# to the bare `rlang::abort()` this replaced ("Coinbase HTTP error <status>\n
# <body>"), so existing tests and downstream message greps keep matching. The
# classes and fields are purely additive.

#' Raise a typed Coinbase HTTP API error
#'
#' Signals a condition classed
#' `c("coinbase_api_error_<status>", "coinbase_api_error",`
#' `"connectcore_api_error_<status>", "connectcore_api_error",`
#' `"connectcore_error")` (on top of rlang's error classes), carrying the HTTP
#' `status`, the request `url` (query-string credentials redacted with
#' [connectcore::scrub_url()]), and the response `body_snippet` as structured
#' fields. The message defaults to the byte-identical
#' `"Coinbase HTTP error <status>\n<body>"` string the funnel signalled before
#' typed conditions existed, so nothing that matched on message text breaks. See
#' [connectcore::connectcore_conditions] for the taxonomy and the subclass recipe.
#'
#' @param status (scalar<count in [100, 599]>) the HTTP status code. Also names
#'   the most specific classes, `coinbase_api_error_<status>` and
#'   `connectcore_api_error_<status>`.
#' @param url (scalar<character> | NULL) the request URL; query-string credentials
#'   are redacted with [connectcore::scrub_url()] before storing on the `url`
#'   field. Default `NULL`.
#' @param body (scalar<character> | NULL) the response body text; stored on the
#'   `body_snippet` field (named `body_snippet`, not `body`, because
#'   `rlang::abort()` reserves `body`). Default `NULL`.
#' @param message (scalar<character> | NULL) the condition message. `NULL`
#'   (default) derives the byte-identical legacy string from `status` and `body`.
#' @return (class<connectcore_error>) never returns normally; signals the classed
#'   condition described above.
#'
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_coinbase_error <- function(status, url = NULL, body = NULL, message = NULL) {
  if (is.null(message)) {
    message <- paste0("Coinbase HTTP error ", status)
    if (!is.null(body)) {
      message <- paste0(message, "\n", body)
    }
  }
  return(rlang::abort(
    message = message,
    class = c(
      sprintf("coinbase_api_error_%d", as.integer(status)),
      "coinbase_api_error",
      sprintf("connectcore_api_error_%d", as.integer(status)),
      "connectcore_api_error",
      "connectcore_error"
    ),
    status = as.integer(status),
    url = connectcore::scrub_url(url),
    body_snippet = body,
    call = rlang::caller_env()
  ))
}
