# File: R/helpers_request.R
# Coinbase-specific request machinery layered on connectcore's transport base.
# The generic funnel (sync/async branch, retry, throttle), the JSON->data.table
# toolkit, and the WebSocket base all live in connectcore; this file keeps only
# what is genuinely Coinbase-specific: JWT (ES256 / EdDSA) request signing, the
# Coinbase error/empty-body envelope, and a thin `coinbase_build_request()` that
# wires those two seams into connectcore::build_request().

#' Load a Coinbase Private Key (EC PEM or base64 Ed25519)
#'
#' Coinbase delivers two key formats: EC (P-256) keys as PEM
#' (`-----BEGIN EC PRIVATE KEY-----`, signed with ES256), and the newer
#' recommended Ed25519 keys as a bare base64 string of the raw key bytes (signed
#' with EdDSA). [openssl::read_key()] reads PEM directly but treats a bare base64
#' string as a file path; for Ed25519 we wrap the raw 32-byte seed in a PKCS#8
#' DER envelope and PEM-encode it so `read_key()` can load it.
#'
#' @param private_key (scalar<character>) the credential private key (PEM or
#'   base64).
#' @return (class<key>) an openssl key object suitable for
#'   [jose::jwt_encode_sig()].
#'
#' @importFrom openssl read_key base64_decode base64_encode
#' @keywords internal
#' @noRd
load_private_key <- function(private_key) {
  assert::assert_nonempty_strings(private_key)
  assert_args_load_private_key(private_key)
  if (grepl("^\\s*-----BEGIN", private_key)) {
    return(assert_return_load_private_key(openssl::read_key(private_key)))
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
  return(assert_return_load_private_key(openssl::read_key(pem)))
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
#' @param keys (list) credentials from [get_api_keys()] (`api_key_name`,
#'   `api_private_key`).
#' @param method (scalar<character>) HTTP method (e.g. `"GET"`, `"POST"`).
#' @param host (scalar<character>) request host without scheme (e.g.
#'   `"api.coinbase.com"`).
#' @param path (scalar<character>) request path without query string
#'   (e.g. `"/api/v3/brokerage/accounts"`).
#' @return (scalar<character>) the encoded JWT.
#'
#' @importFrom jose jwt_claim jwt_encode_sig
#' @importFrom openssl rand_bytes
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
build_jwt <- function(keys, method, host, path) {
  assert_args_build_jwt(keys, method, host, path)
  assert::assert_nonempty_strings(method)
  assert::assert_nonempty_strings(host)
  assert::assert_nonempty_strings(path)
  if (is.null(keys$api_private_key) || !nzchar(keys$api_private_key) || !nzchar(coalesce_null(keys$api_key_name, ""))) {
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

  return(assert_return_build_jwt(jose::jwt_encode_sig(claim, key = key, header = header)))
}

#' Sign a Request with a Coinbase JWT (the `.sign()` seam)
#'
#' The Coinbase implementation of connectcore's auth-agnostic `.sign(req, keys,
#' ctx)` seam. Attaches a `Bearer` JWT whose `uri` claim is derived from the
#' request as it stands; [httr2::url_parse()] splits the path from the query, so
#' the claim correctly excludes any query string regardless of when signing runs
#' in the funnel. `ctx` (connectcore's timestamp source) is unused: the JWT
#' stamps its own `nbf`/`exp` from the local UTC clock.
#'
#' @param req (class<httr2_request>) the request to sign.
#' @param keys (list) credentials with `api_key_name` and `api_private_key`.
#' @return (class<httr2_request>) the signed request.
#'
#' @importFrom httr2 req_headers url_parse
#' @keywords internal
#' @noRd
coinbase_jwt_sign <- function(req, keys) {
  assert_args_coinbase_jwt_sign(req, keys)
  parsed <- httr2::url_parse(req$url)
  method <- "GET"
  if (!is.null(req$method)) {
    method <- req$method
  }
  req <- httr2::req_headers(
    req,
    Authorization = paste0(
      "Bearer ",
      build_jwt(keys, method = method, host = parsed$hostname, path = parsed$path)
    )
  )
  return(assert_return_coinbase_jwt_sign(req))
}

#' Build and Execute a Coinbase API Request
#'
#' Constructs an [httr2::request], optionally JWT-signs it, performs it (sync or
#' async), and parses the Coinbase response envelope. This is the single point
#' through which all Coinbase API calls flow; it is a thin Coinbase-specific
#' wrapper over [connectcore::build_request()] that injects the two seams that
#' differ per venue — JWT signing (the internal `coinbase_jwt_sign()`) and the
#' Coinbase error/empty-body envelope (the internal `parse_coinbase_response()`).
#' Everything else (the
#' sync/async branch, NULL-field stripping, the JSON body, retry, throttle) comes
#' from connectcore.
#'
#' ### Sync vs Async
#' The `.perform` argument controls execution mode:
#' - `httr2::req_perform` (default): synchronous, returns the parsed data.
#' - `httr2::req_perform_promise`: asynchronous, returns a [promises::promise].
#'
#' @param base_url (scalar<character>) the API base URL (scheme + host).
#' @param endpoint (scalar<character>) the API path.
#' @param method (scalar<character>) HTTP method. Default `"GET"`.
#' @param query (list) query parameters. Default `list()`.
#' @param body (list | NULL) request body. Default `NULL`.
#' @param keys (list | NULL) API credentials. When non-NULL the request is
#'   signed. Default `NULL`.
#' @param .perform (function) the httr2 perform function. Default
#'   `httr2::req_perform`.
#' @param .parser (function) post-processing applied to the parsed response body.
#'   Default `identity`.
#' @param is_async (scalar<logical>) whether `.perform` returns promises. Default
#'   `FALSE`.
#' @param timeout (scalar<numeric in ]0, Inf[>) request timeout in seconds.
#'   Default `30`.
#' @return (any | promise<any>) parsed and post-processed API response data, or a
#'   promise thereof.
#' @noassert
#'
#' @importFrom httr2 req_perform
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
  assert::assert_nonempty_strings(base_url)
  assert::assert_nonempty_strings(endpoint)
  assert::assert_nonempty_strings(method)
  return(connectcore::build_request(
    base_url = base_url,
    endpoint = endpoint,
    method = method,
    query = query,
    body = body,
    keys = keys,
    sign = function(req, keys, ctx) coinbase_jwt_sign(req, keys),
    parse_envelope = parse_coinbase_response,
    body_format = "json",
    .perform = .perform,
    .parser = .parser,
    is_async = is_async,
    timeout = timeout,
    user_agent = "dereckscompany/coinbase"
  ))
}

#' Parse and Validate a Coinbase API Response (the `.parse_envelope()` seam)
#'
#' The Coinbase implementation of connectcore's `.parse_envelope(resp)` seam.
#' Extracts JSON from an [httr2::response], validates the HTTP status, and
#' returns the parsed body. Coinbase signals failure with HTTP status codes and
#' an error body containing `error`/`message` (Advanced Trade) or `message`
#' (Exchange); some success responses carry an empty body, which must not be fed
#' to the JSON parser.
#'
#' @param resp (class<httr2_response>) an [httr2::response] object.
#' @return (list) the parsed JSON response body.
#'
#' @importFrom httr2 resp_status resp_body_string
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
parse_coinbase_response <- function(resp) {
  assert_args_parse_coinbase_response(resp)
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
    return(assert_return_parse_coinbase_response(list()))
  }

  # NOTE: simplifyVector = FALSE preserves nested JSON structure faithfully so
  # downstream parsers can flatten it deterministically into data.tables.
  return(assert_return_parse_coinbase_response(jsonlite::fromJSON(body_text, simplifyVector = FALSE)))
}
