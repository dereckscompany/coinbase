# Offline tests for the request/auth layer: key loading (EC + Ed25519),
# the empty-credential guard, and the HTTP-error response path.

test_that("load_private_key reads an EC PEM key", {
  pem <- openssl::write_pem(openssl::ec_keygen("P-256"))
  k <- load_private_key(pem)
  expect_s3_class(k, "key")
})

test_that("load_private_key reconstructs a base64 Ed25519 key and it can sign", {
  ed <- openssl::ed25519_keygen()
  seed <- as.list(ed)$data
  b64 <- openssl::base64_encode(seed)
  k <- load_private_key(b64)
  expect_s3_class(k, "key")
  tok <- jose::jwt_encode_sig(
    jose::jwt_claim(sub = "x", iss = "cdp"),
    key = k,
    header = list(kid = "x", nonce = "ab")
  )
  expect_true(is.character(tok) && nchar(tok) > 0)
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

test_that("parse_coinbase_response returns parsed body on success", {
  resp <- httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw('{"can_trade":true,"x":1}')
  )
  out <- parse_coinbase_response(resp)
  expect_true(out$can_trade)
})
