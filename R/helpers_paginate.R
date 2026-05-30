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

  fetch_page <- function(cursor, page_no) {
    q <- query
    if (!is.null(cursor) && nzchar(cursor)) {
      q$cursor <- cursor
    }
    result <- .req_fn(endpoint = endpoint, query = q)

    return(then_or_now(
      result,
      function(body) {
        items <- body[[items_field]]
        if (!is.null(items) && length(items) > 0L) {
          accumulator[[length(accumulator) + 1L]] <<- items
        }

        has_next <- isTRUE(body$has_next)
        next_cursor <- body$cursor
        more <- has_next &&
          page_no < max_pages &&
          !is.null(next_cursor) &&
          nzchar(next_cursor)

        if (!more) {
          # Flatten the per-page item lists into one list before parsing.
          return(.parser(do.call(c, accumulator)))
        }
        return(fetch_page(next_cursor, page_no + 1L))
      },
      is_async = is_async
    ))
  }

  return(fetch_page(NULL, 1L))
}
