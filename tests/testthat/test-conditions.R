# Typed Coinbase input-validation conditions. Every non-transport abort is raised
# through abort_coinbase_validation_error(), classed c("coinbase_validation_error",
# "coinbase_error") -- coinbase_error is the connector's DOMAIN root, parallel to
# the transport connectcore_error root. The message strings stay byte-identical
# to the bare rlang::abort() calls each site replaced (the goldens below pin
# that). If a golden fails, the backward-compatibility contract broke.

test_that("abort_coinbase_validation_error layers coinbase_validation_error then coinbase_error", {
  err <- tryCatch(coinbase:::abort_coinbase_validation_error("boom"), error = function(e) e)
  expect_identical(
    class(err),
    c("coinbase_validation_error", "coinbase_error", "rlang_error", "error", "condition")
  )
  expect_identical(conditionMessage(err), "boom")
})

test_that("coinbase_validation_error is caught by the coinbase_error root but is NOT a transport error", {
  caught <- tryCatch(coinbase:::abort_coinbase_validation_error("x"), coinbase_error = function(e) "root")
  expect_identical(caught, "root")
  err <- tryCatch(coinbase:::abort_coinbase_validation_error("x"), error = function(e) e)
  expect_false(inherits(err, "connectcore_error"))
})

# ---- Real sites: class, and byte-identical message (golden) ----

test_that("validate_side rejects a bad side with coinbase_validation_error (golden)", {
  err <- tryCatch(coinbase:::validate_side("HODL"), error = function(e) e)
  expect_s3_class(err, "coinbase_validation_error")
  expect_s3_class(err, "coinbase_error")
  expect_identical(conditionMessage(err), "Invalid side 'HODL'. Expected \"BUY\" or \"SELL\".")
})

test_that("validate_symbol rejects a bad product_id with coinbase_validation_error (golden)", {
  err <- tryCatch(coinbase:::validate_symbol("INVALID"), error = function(e) e)
  expect_s3_class(err, "coinbase_validation_error")
  expect_s3_class(err, "coinbase_error")
  expect_identical(
    conditionMessage(err),
    "Invalid product_id 'INVALID'. Expected BASE-QUOTE form, e.g. \"BTC-USD\"."
  )
})
