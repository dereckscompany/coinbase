# Offline tests for the request/auth layer: key loading (EC + Ed25519),
# the empty-credential guard, and the HTTP-error response path.

test_that("load_private_key reads an EC PEM key", {
  pem <- openssl::write_pem(openssl::ec_keygen("P-256"))
  k <- load_private_key(pem)
  expect_s3_class(k, "key")
})

test_that("load_private_key reconstructs the SAME Ed25519 key (pubkey matches, JWT verifies)", {
  ed <- openssl::ed25519_keygen()
  seed <- as.list(ed)$data
  k <- load_private_key(openssl::base64_encode(seed))
  expect_s3_class(k, "key")
  # Must be the original key, not merely a valid one: public keys must match.
  expect_equal(as.list(k$pubkey)$data, as.list(ed$pubkey)$data)
  # And a JWT signed with it must verify against that public key.
  tok <- jose::jwt_encode_sig(
    jose::jwt_claim(sub = "x", iss = "cdp"),
    key = k,
    header = list(kid = "x", nonce = "ab")
  )
  decoded <- jose::jwt_decode_sig(tok, pubkey = ed$pubkey)
  expect_equal(decoded$sub, "x")
})

test_that("load_private_key handles 64-byte (seed||pub) Ed25519 input", {
  ed <- openssl::ed25519_keygen()
  seed <- as.list(ed)$data
  pub <- as.list(ed$pubkey)$data
  k <- load_private_key(openssl::base64_encode(c(seed, pub)))
  expect_equal(as.list(k$pubkey)$data, pub)
})

test_that("load_private_key aborts on a wrong-length / junk base64 key", {
  expect_error(load_private_key(openssl::base64_encode(as.raw(1:10))), "32 or 64")
  expect_error(load_private_key("===="), "32 or 64")
})

test_that("build_jwt aborts clearly when credentials are empty", {
  expect_error(
    build_jwt(list(api_key_name = "", api_private_key = ""), "GET", "api.coinbase.com", "/p"),
    "credentials are not set"
  )
})

test_that("build_jwt nonces are unique even after set.seed (CSPRNG, not sample())", {
  pem <- openssl::write_pem(openssl::ec_keygen("P-256"))
  keys <- list(api_key_name = "organizations/o/apiKeys/k", api_private_key = pem)
  decode_nonce <- function(tok) {
    h <- strsplit(tok, ".", fixed = TRUE)[[1]][1]
    h <- gsub("-", "+", h, fixed = TRUE)
    h <- gsub("_", "/", h, fixed = TRUE)
    pad <- nchar(h) %% 4
    if (pad > 0) {
      h <- paste0(h, strrep("=", 4 - pad))
    }
    return(jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(h)))$nonce)
  }
  set.seed(1)
  n1 <- decode_nonce(build_jwt(keys, "GET", "api.coinbase.com", "/p"))
  set.seed(1)
  n2 <- decode_nonce(build_jwt(keys, "GET", "api.coinbase.com", "/p"))
  expect_false(identical(n1, n2))
  expect_equal(nchar(n1), 64L)
})

test_that("parse_coinbase_response aborts on HTTP >= 400 with status and body", {
  resp <- httr2::response(
    status_code = 404L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw('{"error":"NOT_FOUND","message":"no such order"}')
  )
  expect_error(parse_coinbase_response(resp), "404")
  expect_error(parse_coinbase_response(resp), "NOT_FOUND")
})

test_that("parse_coinbase_response raises a typed condition catchable at three levels", {
  resp <- httr2::response(
    status_code = 429L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw('{"error":"RATE_LIMIT","message":"slow down"}')
  )

  # per-status: catch only 429 without catching the rest of the family
  status_hit <- tryCatch(
    parse_coinbase_response(resp),
    coinbase_api_error_429 = function(e) e
  )
  expect_s3_class(status_hit, "coinbase_api_error_429")
  expect_equal(status_hit$status, 429L)
  expect_match(status_hit$body_snippet, "RATE_LIMIT")

  # package family: any Coinbase HTTP failure
  fam_hit <- tryCatch(parse_coinbase_response(resp), coinbase_api_error = function(e) e)
  expect_s3_class(fam_hit, "coinbase_api_error")

  # connectcore family: any HTTP failure fleet-wide, and any transport failure
  cc_fam <- tryCatch(parse_coinbase_response(resp), connectcore_api_error = function(e) e)
  expect_s3_class(cc_fam, "connectcore_api_error")
  cc_root <- tryCatch(parse_coinbase_response(resp), connectcore_error = function(e) e)
  expect_s3_class(cc_root, "connectcore_error")

  # structured fields present and the class vector is ordered specific -> general
  expect_s3_class(cc_root, "connectcore_api_error_429")
  expect_equal(cc_root$status, 429L)
  expect_true(!is.null(cc_root$url))
  expect_match(cc_root$body_snippet, "slow down")
})

test_that("parse_coinbase_response error message is byte-identical to the legacy string", {
  body_text <- '{"error":"NOT_FOUND","message":"no such order"}'
  resp <- httr2::response(
    status_code = 404L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(body_text)
  )
  err <- tryCatch(parse_coinbase_response(resp), error = function(e) e)
  expect_equal(conditionMessage(err), paste0("Coinbase HTTP error 404\n", body_text))
})

test_that("coinbase_build_request omits NULL body fields (single-field edit) but keeps nested config", {
  captured <- NULL
  fake_perform <- function(req) {
    # connectcore's funnel encodes the body via req_body_json, so req$body$data
    # is the (NULL-stripped) list; serialise it the way httr2 sends it on the
    # wire to assert the exact JSON.
    captured <<- as.character(jsonlite::toJSON(req$body$data, auto_unbox = TRUE, null = "null"))
    return(httr2::response(
      status_code = 200L,
      headers = list(`Content-Type` = "application/json"),
      body = charToRaw("{}")
    ))
  }
  # single-field edit: price is NULL and must be omitted, size kept
  coinbase_build_request(
    base_url = "https://api.coinbase.com",
    endpoint = "/e",
    method = "POST",
    body = list(order_id = "abc", price = NULL, size = "1"),
    .perform = fake_perform
  )
  expect_false(grepl("price", captured))
  expect_true(grepl("\"size\":\"1\"", captured))
  expect_true(grepl("\"order_id\":\"abc\"", captured))

  # nested order_configuration must survive intact
  coinbase_build_request(
    base_url = "https://api.coinbase.com",
    endpoint = "/o",
    method = "POST",
    body = list(product_id = "BTC-USD", order_configuration = list(market_market_ioc = list(quote_size = "10"))),
    .perform = fake_perform
  )
  expect_true(grepl("market_market_ioc", captured))
  expect_true(grepl("\"quote_size\":\"10\"", captured))
})

test_that("coinbase_build_request explodes a multi-value query param (product_ids repeats, no abort)", {
  # Regression: connectcore must set .multi = "explode" in the funnel so a vector
  # product_ids becomes ?product_ids=A&product_ids=B (Coinbase's wire format),
  # NOT abort. Exercised by CoinbaseMarketData$get_best_bid_ask,
  # CoinbaseTrading$get_orders, and CoinbaseTrading$get_fills.
  captured <- NULL
  fake_perform <- function(req) {
    captured <<- req$url
    return(httr2::response(
      status_code = 200L,
      headers = list(`Content-Type` = "application/json"),
      body = charToRaw("{}")
    ))
  }
  expect_no_error(
    coinbase_build_request(
      base_url = "https://api.coinbase.com",
      endpoint = "/api/v3/brokerage/best_bid_ask",
      method = "GET",
      query = list(product_ids = c("BTC-USD", "ETH-USD")),
      .perform = fake_perform
    )
  )
  expect_true(grepl("product_ids=BTC-USD", captured, fixed = TRUE))
  expect_true(grepl("product_ids=ETH-USD", captured, fixed = TRUE))
})

test_that("parse_coinbase_response returns parsed body on success", {
  resp <- httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw('{"can_trade":true,"x":1}')
  )
  out <- parse_coinbase_response(resp)
  expect_true(out$can_trade)
})

test_that("parse_coinbase_response treats an empty 200 body as {} (no premature-EOF crash)", {
  # Some endpoints (e.g. the intraday-margin setter) return 200 with no content.
  empty <- httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = raw(0)
  )
  expect_equal(parse_coinbase_response(empty), list())

  blank <- httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw("   ")
  )
  expect_equal(parse_coinbase_response(blank), list())
})

# -- max_tries: the hard GET-only retry carve-out --

test_that("CoinbaseBase rejects max_tries outside [1, 10]", {
  expect_error(CoinbaseBase$new(keys = NULL, max_tries = 0L))
  expect_error(CoinbaseBase$new(keys = NULL, max_tries = 11L))
})

# `httr2::req_perform()` short-circuits its retry loop whenever the `httr2_mock`
# option is set, so `local_mock_api()` / `local_mocked_responses()` cannot
# exercise retry. We mock the per-attempt fetch (`httr2:::req_perform1`) instead,
# letting `req_perform()` re-drive it against the policy the constructor's
# `max_tries` threaded into `connectcore::build_request()`; `sys_sleep` is
# stubbed so backoff is instant.

test_that("a non-idempotent POST is performed exactly once even with max_tries = 5", {
  base <- CoinbaseBase$new(keys = NULL, max_tries = 5L)
  n <- 0L
  testthat::local_mocked_bindings(
    sys_sleep = function(seconds, ...) invisible(),
    req_perform1 = function(req, req_prep, path, handle, resend_count) {
      n <<- n + 1L
      return(httr2::response(status_code = 500L, body = charToRaw("Internal Server Error")))
    },
    .package = "httr2"
  )
  priv <- base$.__enclos_env__$private
  expect_error(priv$.request(endpoint = "/api/v3/brokerage/orders", method = "POST", auth = FALSE))
  expect_identical(n, 1L) # never a silent resend of an order
})

test_that("a transient 500 on a GET is retried and then succeeds (max_tries = 3)", {
  base <- CoinbaseBase$new(keys = NULL, max_tries = 3L)
  n <- 0L
  testthat::local_mocked_bindings(
    sys_sleep = function(seconds, ...) invisible(),
    req_perform1 = function(req, req_prep, path, handle, resend_count) {
      n <<- n + 1L
      if (n == 1L) {
        return(httr2::response(status_code = 500L, body = charToRaw("Internal Server Error")))
      }
      return(httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw('{"ok":true}')
      ))
    },
    .package = "httr2"
  )
  priv <- base$.__enclos_env__$private
  out <- priv$.request(endpoint = "/api/v3/brokerage/time", method = "GET", auth = FALSE)
  expect_true(out$ok)
  expect_identical(n, 2L) # retried once on the 500, then succeeded
})
