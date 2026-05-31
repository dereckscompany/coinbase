# File: R/helpers_request.R
# Core HTTP request infrastructure for the coinbase package.
# Provides then_or_now(), build_jwt(), coinbase_build_request(), and the
# response parser.

#' Apply Continuation to a Value or Promise
#'
#' Routes a value through `fn` either synchronously or asynchronously depending
#' on whether the caller is in async mode. This is the package's single
#' sync/async branching idiom; it is called from `coinbase_build_request()`,
#' `coinbase_paginate_cursor()`, and `coinbase_fetch_trades_history()`.
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

#' Load a Coinbase Private Key (EC PEM or base64 Ed25519)
#'
#' Coinbase delivers two key formats: EC (P-256) keys as PEM
#' (`-----BEGIN EC PRIVATE KEY-----`, signed with ES256), and the newer
#' recommended Ed25519 keys as a bare base64 string of the raw key bytes (signed
#' with EdDSA). [openssl::read_key()] reads PEM directly but treats a bare base64
#' string as a file path; for Ed25519 we wrap the raw 32-byte seed in a PKCS#8
#' DER envelope and PEM-encode it so `read_key()` can load it.
#'
#' @param private_key Character; the credential private key (PEM or base64).
#' @return An openssl key object suitable for [jose::jwt_encode_sig()].
#'
#' @importFrom openssl read_key base64_decode base64_encode
#' @keywords internal
#' @noRd
load_private_key <- function(private_key) {
  if (grepl("^\\s*-----BEGIN", private_key)) {
    return(openssl::read_key(private_key))
  }
  # Bare base64 => raw Ed25519 key bytes. Coinbase ships 32 (seed) or 64
  # (seed||public) bytes; the seed is the first 32. Wrap in the fixed PKCS#8
  # Ed25519 DER prefix and PEM-encode so openssl::read_key can parse it.
  raw <- openssl::base64_decode(gsub("\\s", "", private_key))
  if (!length(raw) %in% c(32L, 64L)) {
    rlang::abort(paste0(
      "Invalid Ed25519 private key: expected 32 or 64 base64-decoded bytes, got ",
      length(raw),
      ". Check COINBASE_API_PRIVATE_KEY."
    ))
  }
  seed <- raw[seq_len(32L)]
  pkcs8_prefix <- as.raw(c(
    0x30,
    0x2e,
    0x02,
    0x01,
    0x00,
    0x30,
    0x05,
    0x06,
    0x03,
    0x2b,
    0x65,
    0x70,
    0x04,
    0x22,
    0x04,
    0x20
  ))
  der <- c(pkcs8_prefix, seed)
  pem <- paste0(
    "-----BEGIN PRIVATE KEY-----\n",
    openssl::base64_encode(der, linebreaks = TRUE),
    "-----END PRIVATE KEY-----\n"
  )
  return(openssl::read_key(pem))
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
#' @importFrom openssl rand_bytes
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
build_jwt <- function(keys, method, host, path) {
  if (is.null(keys$api_private_key) || !nzchar(keys$api_private_key) || !nzchar(keys$api_key_name %or% "")) {
    rlang::abort(paste0(
      "Coinbase API credentials are not set. Provide them via get_api_keys() ",
      "or the COINBASE_API_KEY_NAME / COINBASE_API_PRIVATE_KEY environment variables."
    ))
  }
  # jose selects the algorithm from the key type: ES256 for EC (P-256) keys,
  # EdDSA for Ed25519 keys -- both of which Coinbase accepts.
  key <- load_private_key(keys$api_private_key)

  now <- as.integer(as.numeric(lubridate::now("UTC")))
  claim <- jose::jwt_claim(
    sub = keys$api_key_name,
    iss = "cdp",
    nbf = now,
    exp = now + 120L,
    uri = paste0(method, " ", host, path)
  )

  header <- list(
    kid = keys$api_key_name,
    # 64 hex chars of single-use entropy from a CSPRNG (NOT base R sample(),
    # which is seedable and would make the anti-replay nonce predictable).
    nonce = paste(format(as.hexmode(as.integer(openssl::rand_bytes(32L))), width = 2L), collapse = "")
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
#' @importFrom httr2 request req_method req_url_path_append req_url_query req_body_raw req_timeout
#' @importFrom httr2 req_perform req_user_agent req_error req_headers url_parse
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
  timeout = 30
) {
  req <- httr2::request(base_url)
  req <- httr2::req_url_path_append(req, endpoint)
  req <- httr2::req_method(req, method)
  req <- httr2::req_timeout(req, timeout)
  req <- httr2::req_user_agent(req, "dereckscompany/coinbase")
  # Surface the API's own error body rather than httr2's generic message.
  req <- httr2::req_error(req, is_error = function(resp) FALSE)

  # JSON body. Strip top-level NULL fields (e.g. an unspecified price or size on
  # a single-field edit) so they are omitted rather than sent as JSON null, matching
  # the reference SDK. Nested objects (order_configuration) are left untouched.
  if (!is.null(body)) {
    body <- body[!vapply(body, is.null, logical(1))]
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

  # Some success responses carry an empty body (e.g. the intraday-margin setter
  # returns HTTP 200 with no content). fromJSON("") would abort with a
  # "premature EOF" parse error, so treat a blank body as an empty object.
  if (!nzchar(trimws(body_text))) {
    return(list())
  }

  # NOTE: simplifyVector = FALSE preserves nested JSON structure faithfully so
  # downstream parsers can flatten it deterministically into data.tables.
  return(jsonlite::fromJSON(body_text, simplifyVector = FALSE))
}
