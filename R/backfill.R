# File: R/backfill.R
# Standalone, instance-free deep trade backfill to CSV.

#' Backfill Coinbase Trade History to CSV
#'
#' Downloads deep tick history for one or more products and writes the results
#' incrementally to a CSV file. Supports resuming a partially completed backfill
#' by reading the existing file and continuing each product from its last
#' recorded trade. This is the foundation of the data-collection pipeline:
#' aggregate the resulting ticks with [trades_to_ohlcv()] for OHLCV at any
#' timeframe.
#'
#' Paging always begins at the most recent trade and walks backwards toward
#' `from`; for a fresh (non-resumed) run, leaving `from` as the default pulls a
#' bounded recent window rather than the product's entire history.
#'
#' @param symbols Character vector of product symbols (e.g.
#'   `c("BTC-USD", "ETH-USD")`). Must not be NULL or empty.
#' @param from POSIXct or numeric; start of the backfill window. Defaults to one
#'   week ago. Tick volume is large, so widen this deliberately.
#' @param to POSIXct or numeric; end of the window. Defaults to the current time.
#' @param file Character; path to the output CSV. Data is appended incrementally
#'   so progress survives interruption.
#' @param base_url Character; Advanced Trade API base URL.
#' @param exchange_base_url Character; Exchange API base URL.
#' @param max_pages Numeric; per-symbol cap on pages fetched. Default `Inf`.
#' @param sleep Numeric; seconds to sleep between symbols to respect rate limits.
#' @param verbose Logical; if `TRUE`, prints progress via [rlang::inform()].
#'
#' @return The file path (invisibly). If any symbols failed, a `"failures"`
#'   attribute is attached: a [data.table::data.table] with columns `symbol`
#'   and `error`.
#'
#' @importFrom lubridate as_datetime now dweeks
#' @importFrom rlang inform warn
#' @export
#'
#' @examples
#' \dontrun{
#' coinbase_backfill_trades(
#'   symbols = c("BTC-USD", "ETH-USD"),
#'   from = lubridate::as_datetime("2026-05-01"),
#'   file = "trades.csv"
#' )
#' }
coinbase_backfill_trades <- function(
  symbols,
  from = lubridate::now("UTC") - lubridate::dweeks(1),
  to = lubridate::now("UTC"),
  file,
  base_url = get_base_url(),
  exchange_base_url = get_exchange_base_url(),
  max_pages = Inf,
  sleep = 0.3,
  verbose = TRUE
) {
  if (is.null(symbols) || length(symbols) == 0L) {
    rlang::abort("`symbols` must be a non-empty character vector.")
  }
  if (missing(file) || !is.character(file) || length(file) != 1L) {
    rlang::abort("`file` must be a single path string.")
  }

  from <- lubridate::as_datetime(from, tz = "UTC")
  to <- lubridate::as_datetime(to, tz = "UTC")

  # Public market data needs no credentials.
  client <- CoinbaseMarketData$new(
    keys = NULL,
    base_url = base_url,
    exchange_base_url = exchange_base_url,
    async = FALSE
  )

  # Resume support: continue each symbol from its last recorded trade.
  last_times <- list()
  file_exists <- file.exists(file)
  if (file_exists) {
    existing <- data.table::fread(file)
    if (nrow(existing) > 0L && all(c("symbol", "time") %in% names(existing))) {
      existing[, time := lubridate::as_datetime(time, tz = "UTC")]
      maxes <- existing[, list(max_time = max(time)), by = symbol]
      last_times <- stats::setNames(as.list(maxes$max_time), maxes$symbol)
    }
  }

  failures <- list()
  wrote_any <- file_exists
  total <- length(symbols)

  for (i in seq_len(total)) {
    sym <- symbols[[i]]
    sym_from <- from
    if (!is.null(last_times[[sym]])) {
      # Offset by 1 second to avoid re-fetching the last stored trade.
      sym_from <- last_times[[sym]] + 1
    }

    if (sym_from >= to) {
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s: skipped (already up to date)", i, total, sym))
      }
      next
    }

    result <- tryCatch(
      client$get_trades_history(sym, start = sym_from, end = to, max_pages = max_pages),
      error = function(e) e
    )

    if (inherits(result, "error")) {
      failures[[length(failures) + 1L]] <- list(symbol = sym, error = conditionMessage(result))
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s: ERROR %s", i, total, sym, conditionMessage(result)))
      }
      next
    }

    if (nrow(result) == 0L) {
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s: 0 rows", i, total, sym))
      }
      next
    }

    result[, symbol := sym]
    data.table::setcolorder(result, c("symbol", "trade_id", "side", "price", "size", "time"))
    data.table::fwrite(result, file, append = wrote_any)
    wrote_any <- TRUE

    if (verbose) {
      rlang::inform(sprintf("[%d/%d] %s: %d trades", i, total, sym, nrow(result)))
    }

    if (sleep > 0 && i < total) {
      Sys.sleep(sleep)
    }
  }

  if (length(failures) > 0L) {
    fail_dt <- data.table::rbindlist(failures)
    attr(file, "failures") <- fail_dt[]
    rlang::warn(sprintf("%d symbol(s) failed; see the 'failures' attribute.", nrow(fail_dt)))
  }

  return(invisible(file))
}
