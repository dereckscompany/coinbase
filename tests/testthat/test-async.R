# Offline tests for the async (promise) execution path: the recursive
# promise-chaining + <<- accumulator in both paginators must work and agree
# with the sync result. Skips cleanly if promises/later are unavailable.

resolve_promise <- function(p) {
  done <- FALSE
  val <- NULL
  err <- NULL
  promises::then(
    p,
    onFulfilled = function(v) {
      val <<- v
      done <<- TRUE
      return(invisible(NULL))
    },
    onRejected = function(e) {
      err <<- e
      done <<- TRUE
      return(invisible(NULL))
    }
  )
  for (i in seq_len(1000L)) {
    if (done) {
      break
    }
    later::run_now(timeout = 0.01)
  }
  if (!is.null(err)) {
    stop(err)
  }
  return(val)
}

test_that("coinbase_paginate_cursor agrees sync vs async over multiple pages", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  pages <- list(
    list(accounts = list(list(uuid = "1"), list(uuid = "2")), has_next = TRUE, cursor = "c1"),
    list(accounts = list(list(uuid = "3")), has_next = FALSE, cursor = "")
  )
  pick <- function(query) {
    idx <- 1L
    if (!is.null(query$cursor)) {
      idx <- as.integer(sub("c", "", query$cursor)) + 1L
    }
    return(pages[[idx]])
  }
  sync <- coinbase_paginate_cursor(
    endpoint = "/x",
    items_field = "accounts",
    .req_fn = function(endpoint, query) return(pick(query)),
    .parser = function(items) length(items),
    is_async = FALSE
  )
  async <- coinbase_paginate_cursor(
    endpoint = "/x",
    items_field = "accounts",
    .req_fn = function(endpoint, query) return(promises::promise_resolve(pick(query))),
    .parser = function(items) length(items),
    is_async = TRUE
  )
  expect_equal(sync, 3L)
  expect_true(inherits(async, "promise"))
  expect_equal(resolve_promise(async), 3L)
})

test_that("coinbase_fetch_trades_history agrees sync vs async", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  raw_page <- function(query) {
    after <- query$after
    limit <- query$limit
    ids <- seq_len(2500L)
    if (!is.null(after)) {
      ids <- ids[ids < after]
    }
    ids <- sort(ids, decreasing = TRUE)
    ids <- ids[seq_len(min(limit, length(ids)))]
    return(lapply(ids, function(id) {
      return(list(
        trade_id = id,
        side = "buy",
        size = "1",
        price = "100",
        time = format(lubridate::as_datetime(id, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
      ))
    }))
  }
  sync <- coinbase_fetch_trades_history(
    "BTC-USD",
    page_limit = 1000L,
    is_async = FALSE,
    .req_fn = function(endpoint, query, .parser) return(.parser(raw_page(query)))
  )
  async <- coinbase_fetch_trades_history(
    "BTC-USD",
    page_limit = 1000L,
    is_async = TRUE,
    .req_fn = function(endpoint, query, .parser) return(promises::promise_resolve(.parser(raw_page(query))))
  )
  expect_equal(nrow(sync), 2500L)
  expect_true(inherits(async, "promise"))
  res <- resolve_promise(async)
  expect_equal(nrow(res), 2500L)
  expect_false(is.unsorted(res$time))
})
