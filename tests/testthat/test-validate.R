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

test_that("coerce_positive_string rejects non-positive / non-numeric input", {
  expect_error(coerce_positive_string("abc", "price"), "positive number")
  expect_error(coerce_positive_string("0", "size"), "positive number")
  expect_error(coerce_positive_string(-5, "price"), "positive number")
  expect_error(coerce_positive_string(c(1, 2), "size"), "positive number")
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
