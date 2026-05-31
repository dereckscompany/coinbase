# Offline tests for credentials, base URLs, JWT signing, and time helpers.

test_that("get_base_url and get_exchange_base_url honor args, env, then defaults", {
  expect_equal(get_base_url("https://x"), "https://x")
  expect_equal(get_base_url(""), "https://api.coinbase.com")
  expect_equal(get_exchange_base_url(""), "https://api.exchange.coinbase.com")
})

test_that("get_api_keys unescapes PEM newlines", {
  keys <- get_api_keys(
    api_key_name = "organizations/o/apiKeys/k",
    api_private_key = "-----BEGIN EC PRIVATE KEY-----\\nABC\\nDEF\\n-----END EC PRIVATE KEY-----\\n"
  )
  expect_equal(keys$api_key_name, "organizations/o/apiKeys/k")
  expect_true(grepl("\n", keys$api_private_key))
  expect_false(grepl("\\\\n", keys$api_private_key))
  expect_true(startsWith(keys$api_private_key, "-----BEGIN EC PRIVATE KEY-----\n"))
})

test_that("get_api_keys warns on empty credentials", {
  expect_warning(
    get_api_keys(api_key_name = "", api_private_key = ""),
    "credentials are empty"
  )
})

test_that("datetime_to_epoch coerces via lubridate and passes NULL through", {
  expect_null(datetime_to_epoch(NULL))
  t <- lubridate::as_datetime("2026-01-01T00:00:00Z")
  expect_equal(datetime_to_epoch(t), as.integer(as.numeric(t)))
})

test_that("iso_to_datetime parses Z timestamps to UTC POSIXct", {
  x <- iso_to_datetime("2026-05-30T18:40:29Z")
  expect_true(inherits(x, "POSIXct"))
  expect_equal(format(x, "%Y-%m-%d %H:%M:%S", tz = "UTC"), "2026-05-30 18:40:29")
})

test_that("iso_to_datetime handles fractional seconds, NA, and vectors", {
  # fractional/nanosecond precision (as the ticker returns)
  frac <- iso_to_datetime("2026-05-30T18:40:29.521516921Z")
  expect_true(inherits(frac, "POSIXct"))
  expect_equal(format(frac, "%Y-%m-%d %H:%M:%S", tz = "UTC"), "2026-05-30 18:40:29")
  # NA passthrough
  expect_true(is.na(iso_to_datetime(NA_character_)))
  # vectorised (suppress the expected parse warning on the NA element)
  v <- suppressWarnings(iso_to_datetime(c("2026-01-01T00:00:00Z", NA_character_, "2026-01-02T00:00:00Z")))
  expect_length(v, 3L)
  expect_true(is.na(v[2]))
  expect_false(is.unsorted(c(as.numeric(v[1]), as.numeric(v[3]))))
})

test_that("datetime_to_epoch round-trips and s_to_datetime is UTC", {
  expect_equal(datetime_to_epoch(s_to_datetime(1780000000)), 1780000000L)
  expect_true(inherits(s_to_datetime(0), "POSIXct"))
})

test_that("build_jwt produces a 3-part ES256 token with a query-less uri claim", {
  # Generate an ephemeral EC P-256 key so the test needs no real credentials.
  sk <- openssl::ec_keygen("P-256")
  pem <- openssl::write_pem(sk)
  keys <- list(api_key_name = "organizations/o/apiKeys/k", api_private_key = pem)

  tok <- build_jwt(keys, method = "GET", host = "api.coinbase.com", path = "/api/v3/brokerage/accounts")
  parts <- strsplit(tok, ".", fixed = TRUE)[[1]]
  expect_length(parts, 3L)

  # Decode header + payload (base64url) and check the critical fields.
  b64url <- function(s) {
    s <- gsub("-", "+", s, fixed = TRUE)
    s <- gsub("_", "/", s, fixed = TRUE)
    pad <- nchar(s) %% 4
    if (pad > 0) {
      s <- paste0(s, strrep("=", 4 - pad))
    }
    return(rawToChar(jsonlite::base64_dec(s)))
  }
  header <- jsonlite::fromJSON(b64url(parts[1]))
  payload <- jsonlite::fromJSON(b64url(parts[2]))

  expect_equal(header$alg, "ES256")
  expect_equal(header$kid, "organizations/o/apiKeys/k")
  expect_true(nzchar(header$nonce))
  expect_equal(payload$iss, "cdp")
  expect_equal(payload$sub, "organizations/o/apiKeys/k")
  # uri must carry method + host + path and NO query string
  expect_equal(payload$uri, "GET api.coinbase.com/api/v3/brokerage/accounts")
  expect_false(grepl("?", payload$uri, fixed = TRUE))
  expect_equal(payload$exp - payload$nbf, 120)
})
