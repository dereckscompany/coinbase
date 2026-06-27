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
#' @param symbols (character) product symbols (e.g. `c("BTC-USD", "ETH-USD")`).
#'   Must not be NULL or empty.
#' @param from (POSIXct | numeric) start of the backfill window. Defaults to one
#'   week ago. Tick volume is large, so widen this deliberately.
#' @param to (POSIXct | numeric) end of the window. Defaults to the current time.
#' @param file (scalar<character>) path to the output CSV. Data is appended
#'   incrementally so progress survives interruption.
#' @param base_url (scalar<character>) Advanced Trade API base URL.
#' @param exchange_base_url (scalar<character>) Exchange API base URL.
#' @param max_pages (scalar<numeric in [1, Inf]>) per-symbol cap on pages
#'   fetched. Default `Inf`.
#' @param sleep (scalar<numeric in [0, Inf[>) seconds to sleep between symbols to
#'   respect rate limits.
#' @param verbose (scalar<logical>) if `TRUE`, prints progress via
#'   [rlang::inform()].
#' @noassert file
#'
#' @return (scalar<character>) the file path (invisibly). If any symbols failed, a
#'   `"failures"` attribute is attached: a [data.table::data.table] with columns
#'   `symbol` and `error`.
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
  for (s in symbols) {
    validate_symbol(s)
  }
  if (missing(file) || !is.character(file) || length(file) != 1L || !nzchar(file)) {
    rlang::abort("`file` must be a single non-empty path string.")
  }
  assert_args_coinbase_backfill_trades(
    symbols,
    from,
    to,
    base_url,
    exchange_base_url,
    max_pages,
    sleep,
    verbose
  )

  from <- lubridate::as_datetime(from, tz = "UTC")
  to <- lubridate::as_datetime(to, tz = "UTC")

  # Public market data needs no credentials.
  client <- CoinbaseMarketData$new(
    keys = NULL,
    base_url = base_url,
    exchange_base_url = exchange_base_url,
    async = FALSE
  )

  # Resume support: continue each symbol from its last recorded trade. We resume
  # from the last stored time *inclusively* (not offset forward) and drop
  # already-stored trade_ids before writing. Offsetting the start time forward
  # would skip any other trades sharing that same second, since ticks are
  # sub-second; deduping on trade_id avoids both gaps and duplicate rows.
  last_times <- list()
  existing_ids <- list()
  file_exists <- file.exists(file)
  resumable <- FALSE
  if (file_exists) {
    existing <- data.table::fread(file)
    if (nrow(existing) > 0L && all(c("symbol", "time", "trade_id") %in% names(existing))) {
      existing[, time := lubridate::as_datetime(time, tz = "UTC")]
      maxes <- existing[, list(max_time = max(time)), by = symbol]
      last_times <- stats::setNames(as.list(maxes$max_time), maxes$symbol)
      ids <- existing[, list(ids = list(unique(trade_id))), by = symbol]
      existing_ids <- stats::setNames(ids$ids, ids$symbol)
      resumable <- TRUE
    } else if (nrow(existing) > 0L) {
      # File exists, has rows, but wrong columns: refuse to append headerless,
      # mismatched data onto it.
      rlang::abort(paste0(
        "Output file '",
        file,
        "' exists but lacks the required columns ",
        "(symbol, trade_id, time). Refusing to append; remove or fix the file."
      ))
    }
  }

  failures <- list()
  # Only append (skip header) when there is a valid, non-empty file to extend.
  wrote_any <- resumable
  total <- length(symbols)

  for (i in seq_len(total)) {
    sym <- symbols[[i]]
    sym_from <- from
    # On resume, walk the full window back to the last stored trade: combining a
    # finite max_pages with a resume could truncate the newest pages and strand a
    # permanent gap (the next resume jumps past it from max(time)).
    sym_max_pages <- max_pages
    if (!is.null(last_times[[sym]])) {
      sym_from <- last_times[[sym]]
      if (is.finite(max_pages)) {
        sym_max_pages <- Inf
        if (verbose) {
          rlang::inform(sprintf("[%d/%d] %s: resuming; ignoring max_pages to avoid a gap", i, total, sym))
        }
      }
    }

    if (sym_from > to) {
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s: skipped (already up to date)", i, total, sym))
      }
      next
    }

    result <- tryCatch(
      client$get_trades_history(sym, start = sym_from, end = to, max_pages = sym_max_pages),
      error = function(e) e
    )

    if (inherits(result, "error")) {
      failures[[length(failures) + 1L]] <- list(symbol = sym, error = conditionMessage(result))
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s: ERROR %s", i, total, sym, conditionMessage(result)))
      }
      next
    }

    # Drop trades already stored for this symbol (boundary-second overlap on resume).
    if (!is.null(existing_ids[[sym]])) {
      result <- result[!trade_id %in% existing_ids[[sym]]]
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

  return(invisible(assert_return_coinbase_backfill_trades(file)))
}
