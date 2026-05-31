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
          as.POSIXct(id, origin = "1970-01-01", tz = "UTC"),
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
    start = as.POSIXct(4000, origin = "1970-01-01", tz = "UTC"),
    page_limit = 1000L,
    .req_fn = make_mock_req_fn(5000L),
    is_async = FALSE
  )
  # ids 4000..5000 inclusive => 1001 trades, none older than start
  expect_true(min(as.numeric(res$time)) >= 4000)
  expect_equal(max(res$trade_id), 5000)
})

test_that("empty universe yields an empty data.table", {
  res <- coinbase_fetch_trades_history(
    product_id = "BTC-USD",
    page_limit = 1000L,
    .req_fn = function(endpoint, query, .parser) .parser(list()),
    is_async = FALSE
  )
  expect_equal(nrow(res), 0L)
})
