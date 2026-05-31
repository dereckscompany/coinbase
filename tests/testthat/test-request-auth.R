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

test_that("coinbase_build_request omits NULL body fields (single-field edit) but keeps nested config", {
  captured <- NULL
  fake_perform <- function(req) {
    b <- req$body$data
    captured <<- if (is.raw(b)) rawToChar(b) else as.character(b)
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
