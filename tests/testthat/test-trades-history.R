# Offline tests for the deep-trade-history cursor-walk (no network).
# A mock .req_fn paginates a synthetic trade universe so we can exercise the
# stop conditions, dedup, and ordering deterministically.

# Build a .req_fn over ids 1..n, where each trade's time == its id (epoch secs).
make_mock_req_fn <- function(n) {
  return(function(endpoint, query, .parser) {
    after <- query$after
    limit <- query$limit
    ids <- seq_len(n)
    if (!is.null(after)) {
      ids <- ids[ids < after]
    }
    ids <- sort(ids, decreasing = TRUE)
    ids <- ids[seq_len(min(limit, length(ids)))]
    raw <- lapply(ids, function(id) {
      return(list(
        trade_id = id,
        side = "buy",
        size = "1",
        price = "100",
        time = format(
          lubridate::as_datetime(id, tz = "UTC"),
          "%Y-%m-%dT%H:%M:%SZ"
        )
      ))
    })
    return(.parser(raw))
  })
}

test_that("cursor-walk pages back to the first trade and returns a sorted, deduped set", {
  res <- coinbase_fetch_trades_history(
    product_id = "BTC-USD",
    page_limit = 1000L,
    .req_fn = make_mock_req_fn(2500L),
    is_async = FALSE
  )
  expect_equal(nrow(res), 2500L)
  expect_equal(length(unique(res$trade_id)), 2500L)
  expect_false(is.unsorted(res$time))
  expect_equal(min(res$trade_id), 1)
  expect_equal(max(res$trade_id), 2500)
})

test_that("max_pages caps the walk", {
  res <- coinbase_fetch_trades_history(
    product_id = "BTC-USD",
    max_pages = 2,
    page_limit = 1000L,
    .req_fn = make_mock_req_fn(5000L),
    is_async = FALSE
  )
  # two full pages of 1000
  expect_equal(nrow(res), 2000L)
})

test_that("start bound stops the walk and filters older trades", {
  res <- coinbase_fetch_trades_history(
    product_id = "BTC-USD",
    start = lubridate::as_datetime(4000, tz = "UTC"),
    page_limit = 1000L,
    .req_fn = make_mock_req_fn(5000L),
    is_async = FALSE
  )
  # ids 4000..5000 inclusive => 1001 trades, none older than start
  expect_true(min(as.numeric(res$time)) >= 4000)
  expect_equal(max(res$trade_id), 5000)
})

test_that("empty universe through get_trades_history() yields a typed empty Trades table", {
  # Drive the PUBLIC method, not the bare impl: an empty fetch must still satisfy
  # the 5-column Trades contract its assert_return enforces, so route an empty
  # trades page (`[]`) for the product and assert the columns and their types.
  # connectcore::mock_response serves the empty-array body verbatim.
  connectcore::local_mock_api(list(
    list(pattern = "/products/BTC-USD/trades", fixture = "[]")
  ))

  # A throwaway EC P-256 key so the pre-request JWT signing succeeds; the mock
  # ignores the Authorization header entirely.
  sk <- openssl::ec_keygen("P-256")
  keys <- list(
    api_key_name = "organizations/o/apiKeys/k",
    api_private_key = openssl::write_pem(sk)
  )
  market <- CoinbaseMarketData$new(keys = keys)

  res <- market$get_trades_history("BTC-USD", max_pages = 1)

  expect_true(data.table::is.data.table(res))
  expect_equal(nrow(res), 0L)
  expect_equal(names(res), c("trade_id", "side", "price", "size", "time"))
  expect_type(res$trade_id, "double")
  expect_type(res$side, "character")
  expect_type(res$price, "double")
  expect_type(res$size, "double")
  expect_s3_class(res$time, "POSIXct")
})

test_that("end bound drops trades newer than `end`", {
  res <- coinbase_fetch_trades_history(
    product_id = "BTC-USD",
    end = lubridate::as_datetime(3000, tz = "UTC"),
    page_limit = 1000L,
    .req_fn = make_mock_req_fn(5000L),
    is_async = FALSE
  )
  expect_true(max(as.numeric(res$time)) <= 3000)
})

test_that("a short final page (fewer than page_limit) ends the walk", {
  calls <- 0
  req <- function(endpoint, query, .parser) {
    calls <<- calls + 1L
    # 10 trades total, page_limit 1000 -> one short page, then stop
    ids <- 10:1
    if (!is.null(query$after)) {
      ids <- integer(0)
    }
    raw <- lapply(ids, function(id) {
      return(list(
        trade_id = id,
        side = "buy",
        size = "1",
        price = "100",
        time = format(lubridate::as_datetime(id, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
      ))
    })
    return(.parser(raw))
  }
  res <- coinbase_fetch_trades_history("BTC-USD", page_limit = 1000L, .req_fn = req, is_async = FALSE)
  expect_equal(nrow(res), 10L)
  expect_equal(calls, 1L)
})

test_that("duplicate trades across page overlap are deduped by trade_id", {
  # Mock returns the boundary trade inclusively (id <= after), creating overlap.
  req <- function(endpoint, query, .parser) {
    after <- query$after
    ids <- seq_len(1500L)
    if (!is.null(after)) {
      ids <- ids[ids <= after]
    }
    ids <- sort(ids, decreasing = TRUE)
    ids <- ids[seq_len(min(query$limit, length(ids)))]
    raw <- lapply(ids, function(id) {
      return(list(
        trade_id = id,
        side = "buy",
        size = "1",
        price = "100",
        time = format(lubridate::as_datetime(id, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
      ))
    })
    return(.parser(raw))
  }
  res <- coinbase_fetch_trades_history("BTC-USD", page_limit = 1000L, .req_fn = req, is_async = FALSE)
  expect_equal(length(unique(res$trade_id)), nrow(res))
  expect_equal(nrow(res), 1500L)
})
