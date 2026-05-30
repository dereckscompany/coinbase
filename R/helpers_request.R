# File: R/helpers_request.R
# Core HTTP request infrastructure for the coinbase package.
# Provides then_or_now(), build_jwt(), coinbase_build_request(), and the
# response parser.

#' Apply Continuation to a Value or Promise
#'
#' Routes a value through `fn` either synchronously or asynchronously depending
#' on whether the caller is in async mode. This is the single sync/async
#' branching point in the package -- called only from `.request()`.
#'
#' @param x A value or a [promises::promise].
#' @param fn A function to apply to the resolved value of `x`.
#' @param is_async Logical; whether the caller is in async mode.
#' @return If `is_async`, returns `promises::then(x, fn)`. Otherwise returns `fn(x)`.
#' @keywords internal
#' @noRd
then_or_now <- function(x, fn, is_async = FALSE) {
  if (is_async) {
    return(promises::then(x, fn))
  }
  return(fn(x))
}

#' Build a Coinbase JWT for Request Authentication
#'
#' Constructs the short-lived JSON Web Token that authenticates Advanced Trade
#' API requests. The token is signed with the credential's private key and
#' carries the request method and path in its `uri` claim.
#'
#' ### Signing algorithm
#' The algorithm is selected from the key type: EC (P-256) keys are signed with
#' `ES256`; Ed25519 keys with `EdDSA`. Coinbase accepts either.
#'
#' ### The `uri` claim
#' The `uri` claim must be `"<METHOD> <host><path>"` and **must exclude any query
#' string** (e.g. `"GET api.coinbase.com/api/v3/brokerage/accounts"`, not
#' `"...accounts?limit=3"`). A mismatched `uri` yields HTTP 401.
#'
#' @param keys List of credentials from [get_api_keys()] (`api_key_name`,
#'   `api_private_key`).
#' @param method Character; HTTP method (e.g. `"GET"`, `"POST"`).
#' @param host Character; request host without scheme (e.g. `"api.coinbase.com"`).
#' @param path Character; request path without query string
#'   (e.g. `"/api/v3/brokerage/accounts"`).
#' @return Character; the encoded JWT.
#'
#' @importFrom jose jwt_claim jwt_encode_sig
#' @importFrom openssl read_key
#' @keywords internal
#' @noRd
build_jwt <- function(keys, method, host, path) {
  key <- openssl::read_key(keys$api_private_key)

  alg <- if (inherits(key, "ed25519")) "EdDSA" else "ES256"

  now <- as.integer(unclass(Sys.time()))
  # Backdate nbf by a few seconds as clock-skew tolerance: if the client clock
  # runs ahead of Coinbase's, an nbf of exactly `now` is briefly "not yet valid".
  claim <- jose::jwt_claim(
    sub = keys$api_key_name,
    iss = "cdp",
    nbf = now - 5L,
    exp = now + 120L,
    uri = paste0(method, " ", host, path)
  )

  header <- list(
    kid = keys$api_key_name,
    # 64 hex chars of single-use entropy, per Coinbase's reference implementation.
    nonce = paste(format(as.hexmode(sample(0:255, 32L, replace = TRUE)), width = 2L), collapse = "")
  )

  return(jose::jwt_encode_sig(claim, key = key, header = header))
}

#' Build and Execute a Coinbase API Request
#'
#' Constructs an [httr2::request], optionally attaches a signed JWT, performs it
#' via the supplied `.perform` function, and parses the JSON response. This is
#' the single point through which all Coinbase API calls flow.
#'
#' ### Sync vs Async
#' The `.perform` argument controls execution mode:
#' - `httr2::req_perform` (default): synchronous, returns an [httr2::response].
#' - `httr2::req_perform_promise`: asynchronous, returns a [promises::promise].
#'
#' @param base_url Character; the API base URL (scheme + host).
#' @param endpoint Character; the API path.
#' @param method Character; HTTP method. Default `"GET"`.
#' @param query Named list; query parameters. Default `list()`.
#' @param body Named list or NULL; request body. Default `NULL`.
#' @param keys List or NULL; API credentials. When non-NULL the request is
#'   signed. Default `NULL`.
#' @param .perform Function; the httr2 perform function. Default `httr2::req_perform`.
#' @param .parser Function; post-processing applied to the parsed response body.
#'   Default `identity`.
#' @param is_async Logical; whether `.perform` returns promises. Default `FALSE`.
#' @param timeout Numeric; request timeout in seconds. Default `30`.
#' @return Parsed and post-processed API response data, or a promise thereof.
#'
#' @param max_tries Integer; total attempts on transient failures (HTTP 401,
#'   408, 429, 5xx) with exponential backoff. Default 5. Coinbase intermittently
#'   rejects valid tokens with a bare 401 (e.g. while a freshly-created API key
#'   propagates across its backends); a byte-identical token then succeeds on
#'   retry. A genuinely invalid credential fails every attempt and still
#'   surfaces after retries are exhausted.
#' @importFrom httr2 request req_method req_url_path_append req_url_query req_body_raw req_timeout req_perform req_user_agent req_error req_headers req_retry resp_status url_parse
#' @importFrom jsonlite toJSON
#' @export
coinbase_build_request <- function(
  base_url,
  endpoint,
  method = "GET",
  query = list(),
  body = NULL,
  keys = NULL,
  .perform = httr2::req_perform,
  .parser = identity,
  is_async = FALSE,
  timeout = 30,
  max_tries = 5
) {
  req <- httr2::request(base_url)
  req <- httr2::req_url_path_append(req, endpoint)
  req <- httr2::req_method(req, method)
  req <- httr2::req_timeout(req, timeout)
  req <- httr2::req_user_agent(req, "dereckscompany/coinbase")
  # Surface the API's own error body rather than httr2's generic message.
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  # Retry transient failures with exponential backoff. Coinbase intermittently
  # rejects valid tokens with a bare 401 (notably while a newly-created API key
  # is still propagating across its backends); the identical token succeeds on a
  # subsequent attempt. Permanently invalid credentials fail every attempt and
  # still surface once retries are exhausted.
  req <- httr2::req_retry(
    req,
    max_tries = max_tries,
    is_transient = function(resp) {
      httr2::resp_status(resp) %in% c(401L, 408L, 429L, 500L, 502L, 503L, 504L)
    },
    # The transient 401 typically clears on the very next attempt, so use a
    # short jittered backoff rather than slow exponential growth. A genuine
    # Retry-After header (e.g. on 429) still takes precedence.
    backoff = function(attempt) stats::runif(1, 0.2, 0.6)
  )

  # JSON body
  if (!is.null(body)) {
    body_json <- jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")
    req <- httr2::req_body_raw(req, body_json, type = "application/json")
  }

  # Sign before query params are appended: the JWT `uri` claim excludes the
  # query string, so we derive the signing path from the URL as it stands now.
  if (!is.null(keys)) {
    parsed <- httr2::url_parse(req$url)
    req <- httr2::req_headers(
      req,
      Authorization = paste0(
        "Bearer ",
        build_jwt(keys, method = method, host = parsed$hostname, path = parsed$path)
      )
    )
  }

  # Query parameters (drop NULLs) appended after signing.
  query <- query[!vapply(query, is.null, logical(1))]
  if (length(query) > 0) {
    req <- httr2::req_url_query(req, !!!query, .multi = "explode")
  }

  result <- .perform(req)

  return(then_or_now(
    result,
    function(resp) {
      return(.parser(parse_coinbase_response(resp)))
    },
    is_async = is_async
  ))
}

#' Parse and Validate a Coinbase API Response
#'
#' Extracts JSON from an [httr2::response], validates the HTTP status, and
#' returns the parsed body. Coinbase signals failure with HTTP status codes and
#' an error body containing `error`/`message` (Advanced Trade) or `message`
#' (Exchange).
#'
#' @param resp An [httr2::response] object.
#' @return The parsed JSON response body.
#'
#' @importFrom httr2 resp_status resp_body_string
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
parse_coinbase_response <- function(resp) {
  status <- httr2::resp_status(resp)
  body_text <- tryCatch(
    httr2::resp_body_string(resp),
    error = function(e) ""
  )

  if (status >= 400L) {
    rlang::abort(paste0("Coinbase HTTP error ", status, "\n", body_text))
  }

  # NOTE: simplifyVector = FALSE preserves nested JSON structure faithfully so
  # downstream parsers can flatten it deterministically into data.tables.
  return(jsonlite::fromJSON(body_text, simplifyVector = FALSE))
}
