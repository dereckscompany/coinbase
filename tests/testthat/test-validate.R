# Offline tests for input validators, especially the money-precision contract.

test_that("coerce_positive_string preserves full precision (never 7-sig-fig rounds)", {
  # Character inputs must come back byte-for-byte (this is money to the exchange).
  expect_equal(coerce_positive_string("104250.42", "price"), "104250.42")
  expect_equal(coerce_positive_string("1234567.89", "price"), "1234567.89")
  expect_equal(coerce_positive_string("0.12345678", "size"), "0.12345678")
  expect_equal(coerce_positive_string("0.00000001", "size"), "0.00000001")
  expect_equal(coerce_positive_string("99999.99999999", "price"), "99999.99999999")
  expect_equal(coerce_positive_string("  73937.19  ", "price"), "73937.19")
  # Numeric / scientific inputs are formatted full-precision, non-scientific.
  expect_equal(coerce_positive_string(1e-8, "size"), "0.00000001")
  expect_equal(coerce_positive_string("1e-8", "size"), "0.00000001")
  expect_equal(coerce_positive_string(73937.123456, "price"), "73937.123456")
  # Stays correct and deterministic regardless of options(digits).
  old <- options(digits = 7)
  on.exit(options(old), add = TRUE)
  expect_equal(coerce_positive_string("1234567.89", "price"), "1234567.89")
  expect_equal(coerce_positive_string(73937.123456, "price"), "73937.123456")
})

test_that("coerce_positive_string rejects non-positive / non-numeric / non-finite input", {
  expect_error(coerce_positive_string("abc", "price"), "positive")
  expect_error(coerce_positive_string("0", "size"), "positive")
  expect_error(coerce_positive_string(-5, "price"), "positive")
  expect_error(coerce_positive_string(c(1, 2), "size"), "positive")
  expect_error(coerce_positive_string("Inf", "price"), "positive")
  expect_error(coerce_positive_string("Infinity", "price"), "positive")
  expect_error(coerce_positive_string("1e999", "size"), "positive") # overflow -> Inf
  expect_error(coerce_positive_string("NaN", "price"), "positive")
})

test_that("coerce_positive_string normalises non-canonical tokens to the validated number", {
  # The token sent must equal the validated number, never the raw spelling.
  expect_equal(coerce_positive_string("0x10", "price"), "16")
  expect_equal(coerce_positive_string("+5", "size"), "5")
  expect_equal(coerce_positive_string(".5", "price"), "0.5")
  expect_equal(coerce_positive_string("1.", "size"), "1")
  expect_equal(coerce_positive_string("5e2", "price"), "500")
})

test_that("stringify_order_config validates + stringifies money leaves, leaves others", {
  cfg <- stringify_order_config(list(
    limit_limit_gtc = list(
      base_size = 0.00000001,
      limit_price = 50000.123456789,
      post_only = TRUE,
      stop_direction = "STOP_DIRECTION_STOP_DOWN"
    )
  ))
  inner <- cfg$limit_limit_gtc
  expect_equal(inner$base_size, "0.00000001")
  expect_equal(inner$limit_price, "50000.123456789")
  expect_identical(inner$post_only, TRUE) # logical untouched
  expect_equal(inner$stop_direction, "STOP_DIRECTION_STOP_DOWN") # enum untouched
  # existing strings are left as-is
  cfg2 <- stringify_order_config(list(market_market_ioc = list(quote_size = "10")))
  expect_equal(cfg2$market_market_ioc$quote_size, "10")
})

test_that("stringify_order_config rejects malformed money leaves (Inf/NaN/negative/zero)", {
  expect_error(stringify_order_config(list(limit_limit_gtc = list(base_size = Inf))), "finite")
  expect_error(stringify_order_config(list(limit_limit_gtc = list(base_size = NaN))), "positive")
  expect_error(stringify_order_config(list(market_market_ioc = list(quote_size = -10))), "positive")
  expect_error(stringify_order_config(list(market_market_ioc = list(quote_size = 0))), "positive")
  expect_error(stringify_order_config(list(limit_limit_gtc = list(base_size = "Inf"))), "finite")
})

test_that("money formatting is locale-independent (OutDec comma)", {
  old <- options(OutDec = ",")
  on.exit(options(old), add = TRUE)
  expect_equal(coerce_positive_string(0.5, "size"), "0.5")
  expect_equal(coerce_positive_string(50000.5, "price"), "50000.5")
  cfg <- stringify_order_config(list(limit_limit_gtc = list(base_size = 0.5)))
  expect_equal(cfg$limit_limit_gtc$base_size, "0.5")
})

test_that("validate_order_config rejects degenerate inputs", {
  expect_error(validate_order_config(list(a = 1, b = 2)), "single-key")
  expect_error(validate_order_config(list(1)), "single-key") # unnamed
  expect_error(validate_order_config(data.frame(x = 1)), "single-key")
  expect_silent(validate_order_config(list(market_market_ioc = list(quote_size = "10"))))
})

test_that("validate_side normalises case and rejects junk", {
  expect_equal(validate_side("buy"), "BUY")
  expect_equal(validate_side("Sell"), "SELL")
  expect_error(validate_side("bid"), "BUY")
})
