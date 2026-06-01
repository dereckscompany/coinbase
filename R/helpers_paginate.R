# File: R/helpers_paginate.R
# Body-cursor pagination for Advanced Trade list endpoints (accounts, orders,
# fills). These endpoints return { <items_field>: [...], cursor, has_next };
# pages are walked by passing the previous response's `cursor` until `has_next`
# is false. This is distinct from the Exchange trades walk (which pages on the
# smallest trade_id seen) implemented in impl_trades.R.

# Walk a Cursor-Paginated Advanced Trade Endpoint
#
# @param endpoint Character; the API path.
# @param query Named list; base query parameters (cursor is added per page).
# @param items_field Character; the response field holding the page's items.
# @param .req_fn Function(endpoint, query) -> parsed body (or promise); performs
#   one request through the owning client and returns the raw parsed JSON body.
# @param .parser Function; applied to the accumulated list of items at the end.
#   Default identity.
# @param max_pages Numeric; cap on pages fetched. Default Inf.
# @param is_async Logical; whether .req_fn returns promises.
# @return The parsed accumulated items, or a promise thereof.
coinbase_paginate_cursor <- function(
  endpoint,
  query = list(),
  items_field,
  .req_fn,
  .parser = identity,
  max_pages = Inf,
  is_async = FALSE
) {
  accumulator <- list()

  request_page <- function(cursor) {
    q <- query
    if (!is.null(cursor) && nzchar(cursor)) {
      q$cursor <- cursor
    }
    return(.req_fn(endpoint = endpoint, query = q))
  }

  finish <- function() {
    # Flatten the per-page item lists into one list before parsing.
    return(.parser(do.call(c, accumulator)))
  }

  # Accumulate one page's items and decide whether to keep paging. Pure logic,
  # shared by the synchronous loop and the asynchronous chain; returns `done`
  # and the `next_cursor` to request.
  step <- function(body, page_no, cursor) {
    items <- body[[items_field]]
    if (!is.null(items) && length(items) > 0L) {
      accumulator[[length(accumulator) + 1L]] <<- items
    }

    # Some endpoints omit has_next entirely (e.g. the fills endpoint returns
    # only `fills` + `cursor`). When it is absent, treat it as TRUE and let the
    # cursor guards terminate the walk; otherwise honour it. The repeated-cursor
    # guard ensures forward progress now that the sync path is a loop.
    has_next <- TRUE
    if ("has_next" %in% names(body)) {
      has_next <- isTRUE(body$has_next)
    }
    next_cursor <- body$cursor
    more <- has_next &&
      page_no < max_pages &&
      !is.null(next_cursor) &&
      nzchar(next_cursor) &&
      !identical(next_cursor, cursor)
    return(list(done = !more, next_cursor = next_cursor))
  }

  # Async: chain pages through the promise event loop (the call stack unwinds
  # between pages).
  if (is_async) {
    fetch_page <- function(cursor, page_no) {
      return(promises::then(request_page(cursor), function(body) {
        outcome <- step(body, page_no, cursor)
        if (outcome$done) {
          return(finish())
        }
        return(fetch_page(outcome$next_cursor, page_no + 1L))
      }))
    }
    return(fetch_page(NULL, 1L))
  }

  # Sync: iterate, so a long cursor walk does not overflow the call stack.
  cursor <- NULL
  page_no <- 1L
  repeat {
    body <- request_page(cursor)
    outcome <- step(body, page_no, cursor)
    if (outcome$done) {
      break
    }
    cursor <- outcome$next_cursor
    page_no <- page_no + 1L
  }
  return(finish())
}
