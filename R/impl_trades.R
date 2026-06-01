# File: R/impl_trades.R
# Shared deep-trade-history implementation used by both
# CoinbaseMarketData$get_trades_history() and coinbase_backfill_trades().
# Walks the Exchange /products/{id}/trades endpoint backwards in time by
# paginating on the `after` cursor (the smallest trade_id seen), accumulating
# pages until a stop condition is met, then deduplicates and sorts ascending.
#
# This function is instance-free: it takes a .req_fn callback so it works
# identically in sync and async modes.

# Fetch Deep Trade History from Coinbase
#
# @param product_id Character; the pair symbol, e.g. "BTC-USD".
# @param start POSIXct/numeric or NULL; stop paging once trades older than this
#   are reached. NULL walks back to the product's first trade.
# @param end POSIXct/numeric or NULL; drop trades newer than this from the
#   result. Paging always begins at the most recent trade.
# @param max_pages Numeric; cap on pages fetched (each up to `page_limit`
#   trades). Default Inf.
# @param page_limit Integer; trades per page (max 1000). Default 1000.
# @param .req_fn Function(endpoint, query, .parser) -> data.table (or promise);
#   performs one request through the owning client.
# @param is_async Logical; whether .req_fn returns promises.
# @return A data.table of trades (trade_id, side, price, size, time) sorted
#   ascending by time, or a promise thereof.
coinbase_fetch_trades_history <- function(
  product_id,
  start = NULL,
  end = NULL,
  max_pages = Inf,
  page_limit = 1000L,
  .req_fn,
  is_async = FALSE
) {
  start_s <- NULL
  if (!is.null(start)) {
    start_s <- as.numeric(lubridate::as_datetime(start, tz = "UTC"))
  }
  end_s <- NULL
  if (!is.null(end)) {
    end_s <- as.numeric(lubridate::as_datetime(end, tz = "UTC"))
  }

  accumulator <- list()

  combine <- function() {
    if (length(accumulator) == 0L) {
      return(data.table::data.table()[])
    }
    dt <- data.table::rbindlist(accumulator, fill = TRUE)
    # The 1-trade cursor overlap between pages can repeat a trade; dedup by id.
    dt <- unique(dt, by = "trade_id")
    if (!is.null(start_s)) {
      dt <- dt[as.numeric(time) >= start_s]
    }
    if (!is.null(end_s)) {
      dt <- dt[as.numeric(time) <= end_s]
    }
    data.table::setorder(dt, time, trade_id)
    return(dt[])
  }

  request_page <- function(after) {
    query <- list(limit = as.integer(page_limit), after = after)
    return(.req_fn(
      endpoint = paste0("/products/", product_id, "/trades"),
      query = query,
      .parser = parse_trades
    ))
  }

  # Accumulate one fetched page and decide whether to keep paging. Pure logic,
  # shared by both the synchronous loop and the asynchronous promise chain; it
  # returns `done` (stop now) and `next_after` (the cursor for the older page).
  step <- function(dt, page_no) {
    if (nrow(dt) > 0L) {
      accumulator[[length(accumulator) + 1L]] <<- dt
    }

    # Stop when: the page came back empty, the API returned fewer than a full
    # page (start of history), we've paged past the requested start time, we've
    # hit the page cap, or we've reached the first-ever trade.
    min_id <- 0
    if (nrow(dt) > 0L) {
      min_id <- min(dt$trade_id)
    }
    reached_start <- !is.null(start_s) && nrow(dt) > 0L && min(as.numeric(dt$time)) <= start_s
    exhausted <- nrow(dt) < page_limit
    reached_cap <- page_no >= max_pages
    done <- nrow(dt) == 0L || exhausted || reached_start || reached_cap || min_id <= 1
    return(list(done = done, next_after = min_id))
  }

  # Async: chain pages through the promise event loop. Each continuation runs as
  # a fresh task, so the call stack unwinds between pages and a deep walk does
  # not accumulate stack frames.
  if (is_async) {
    fetch_page <- function(after, page_no) {
      return(promises::then(request_page(after), function(dt) {
        outcome <- step(dt, page_no)
        if (outcome$done) {
          return(combine())
        }
        # Next (older) page: trades with id strictly less than the smallest seen.
        return(fetch_page(outcome$next_after, page_no + 1L))
      }))
    }
    return(fetch_page(NULL, 1L))
  }

  # Sync: iterate. A loop (not self-recursion) means a backfill all the way to a
  # product's first-ever trade does not overflow the call stack, whatever the
  # page count.
  after <- NULL
  page_no <- 1L
  repeat {
    dt <- request_page(after)
    outcome <- step(dt, page_no)
    if (outcome$done) {
      break
    }
    after <- outcome$next_after
    page_no <- page_no + 1L
  }
  return(combine())
}
