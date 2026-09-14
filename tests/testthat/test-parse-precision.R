# Precision regression: every numeric field Coinbase reports must survive
# parsing at full double precision, and every field the parser deliberately
# keeps as a STRING (the ticker's own price/quantity strings) must be returned
# byte-identical -- never silently coerced to numeric. No round(), signif(),
# sprintf("%.Nf"), format(nsmall = ), or other narrowing cast may ever sit
# between the venue's own value and what this package returns.
#
# Why this test exists: on 2026-09-13 the fleet found every Hyperliquid candle
# in the data lake had been stored to four decimal places for months -- a coin
# priced below a cent (e.g. "0.000212") lost almost all of its information,
# and a strategy that ranks coins by calmness ranked them wrongly as a direct
# result. The cause traced to a re-serialisation default in the data scraper
# (since fixed), NOT to the venue connectors: this package's own parse path
# (`parse_candles()` / `nth_num()` in R/helpers_parse.R, a plain
# `as.numeric()` off the venue's own JSON number; `get_ticker()`'s selective
# `as.numeric()` cast, which touches only its named price/quantity columns)
# was proven correct. This test pins that fact for Coinbase so the layer that
# is currently correct STAYS correct: if anyone later adds a
# round()/signif()/sprintf("%.4f")/format(nsmall = ) or a narrowing cast to a
# parse helper, it fails immediately.
#
# Drives the real public client methods (get_ohlcv / get_ticker) through the
# shared connectcore mock harness (a URL-pattern route table +
# local_mock_api()), exactly as test-client-endpoints.R does, with a synthetic
# fixture authored as raw JSON text (never built from an R list +
# jsonlite::toJSON()) so the exact wire digits/strings below are what the
# parser actually sees -- never a private helper reimplemented here. Uses
# expect_identical() throughout, never expect_equal()'s tolerance, because
# tolerance is exactly what would hide this defect.

# A throwaway EC P-256 key so JWT signing (which runs before the request)
# succeeds; the mock ignores the Authorization header entirely.
.precision_sk <- openssl::ec_keygen("P-256")
.precision_keys <- list(
  api_key_name = "organizations/o/apiKeys/k",
  api_private_key = openssl::write_pem(.precision_sk)
)

# ---- fixture: decimal values/strings with many significant digits -----------

# A value just under 2^53 (the largest integer a double represents exactly),
# used as a character-typed identifier (`trade_id`, sent here as the venue's
# own quoted string) to prove an identifier-shaped column is never
# accidentally coerced to numeric.
.precision_big_id <- "9007199254740991"

.precision_strings <- list(
  a = "0.00023456789",
  b = "12345.678901234",
  c = "0.000000123456",
  d = "1e-10"
)

# The Exchange candles endpoint sends bare JSON numbers, positional
# [time, low, high, open, close, volume] -- authored as literal text so the
# exact wire digits below are what jsonlite::fromJSON() actually parses.
.precision_candles_json <- sprintf(
  "[[1700000000,%s,%s,%s,%s,%s]]",
  .precision_strings$c,
  .precision_strings$b,
  .precision_strings$a,
  .precision_strings$d,
  .precision_strings$b
)

# The ticker endpoint sends price/quantity fields as quoted decimal strings.
.precision_ticker_json <- sprintf(
  paste0(
    '{"ask":"%s","bid":"%s","volume":"%s","trade_id":"%s","price":"%s",',
    '"size":"%s","time":"2026-06-27T17:45:15.935911839Z","rfq_volume":"%s"}'
  ),
  .precision_strings$a,
  .precision_strings$b,
  .precision_strings$c,
  .precision_big_id,
  .precision_strings$d,
  .precision_strings$a,
  .precision_strings$b
)

# A tiny URL-pattern route table covering exactly the two endpoints this test
# drives, built the same way the shared mock_router.R does, but with a
# synthetic high-precision fixture instead of the captured real-shaped
# fixtures.
precision_routes <- function() {
  return(list(
    list(pattern = "/products/BTC-USD/candles", fixture = .precision_candles_json),
    list(pattern = "/products/BTC-USD/ticker", fixture = .precision_ticker_json)
  ))
}

# A shared digit-level check: sprintf("%.17g", .) prints enough significant
# digits to uniquely round-trip an IEEE-754 double, so if the parser silently
# narrowed the value (round()/signif()/a %.Nf format), the 17-digit rendering
# of the parsed value would diverge from the 17-digit rendering of the
# fixture's own as.numeric() value.
expect_full_precision <- function(actual, fixture_string) {
  expected <- as.numeric(fixture_string)
  expect_identical(actual, expected)
  return(expect_identical(sprintf("%.17g", actual), sprintf("%.17g", expected)))
}

precision_market <- function() {
  return(CoinbaseMarketData$new(keys = .precision_keys))
}

# ---- candle/kline path: get_ohlcv --------------------------------------------

test_that("get_ohlcv preserves full OHLCV precision through the real parse path", {
  connectcore::local_mock_api(precision_routes())
  dt <- precision_market()$get_ohlcv("BTC-USD", granularity = "1day")

  expect_identical(nrow(dt), 1L)
  expect_full_precision(dt$low, .precision_strings$c)
  expect_full_precision(dt$high, .precision_strings$b)
  expect_full_precision(dt$open, .precision_strings$a)
  expect_full_precision(dt$close, .precision_strings$d)
  expect_full_precision(dt$volume, .precision_strings$b)
})

# ---- ticker/market-data snapshot path: get_ticker ----------------------------

test_that("get_ticker preserves full price precision and leaves the identifier untouched", {
  connectcore::local_mock_api(precision_routes())
  dt <- precision_market()$get_ticker("BTC-USD")

  expect_identical(nrow(dt), 1L)
  expect_full_precision(dt$ask, .precision_strings$a)
  expect_full_precision(dt$bid, .precision_strings$b)
  expect_full_precision(dt$volume, .precision_strings$c)
  expect_full_precision(dt$price, .precision_strings$d)
  expect_full_precision(dt$size, .precision_strings$a)
  # `trade_id` is outside get_ticker()'s named numeric-coercion list
  # (ask/bid/price/size/volume/rfq_volume) and must stay exactly as Coinbase
  # sent it: character, byte-identical, never swept up by a careless blanket
  # coercion.
  expect_type(dt$trade_id, "character")
  expect_identical(dt$trade_id, .precision_big_id)
})
