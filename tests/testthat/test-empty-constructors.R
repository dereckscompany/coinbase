# Guards the typed-empty invariant: every fixed-shape parser's empty branch must
# return a zero-row data.table that still carries its full typed column set (and
# no list column), never a column-less `data.table()`. A column-less empty would
# silently violate each method's `assert_has_columns` @return contract on an
# empty universe / flat account / quiet window. Coinbase extracts a named
# `empty_dt_*()` constructor for every reused fixed shape (see R/helpers_parse.R);
# this file proves each one, and the parser that returns it on empty input.

# Every extracted empty-table constructor, and the datetime columns it must carry
# as POSIXct (empty branch built with the same helper as the populated branch so
# class and tz match). Datetime columns follow I.2.5: `datetime` for the bar
# reference time, `timestamp` for the event/transaction time, venue-meaningful
# extras (`end_time`, `expiration_time`) under their native names.
empty_constructors <- list(
  empty_dt_products = list(ctor = empty_dt_products, datetime_cols = character(0)),
  empty_dt_ohlcv = list(ctor = empty_dt_ohlcv, datetime_cols = "datetime"),
  empty_dt_trades = list(ctor = empty_dt_trades, datetime_cols = "timestamp"),
  empty_dt_accounts = list(ctor = empty_dt_accounts, datetime_cols = c("created_at", "updated_at")),
  empty_dt_fees = list(ctor = empty_dt_fees, datetime_cols = character(0)),
  empty_dt_orders = list(ctor = empty_dt_orders, datetime_cols = c("timestamp", "end_time")),
  empty_dt_fills = list(ctor = empty_dt_fills, datetime_cols = "timestamp"),
  empty_dt_preview = list(ctor = empty_dt_preview, datetime_cols = character(0)),
  empty_dt_create_order_ack = list(ctor = empty_dt_create_order_ack, datetime_cols = character(0)),
  empty_dt_edit_order_ack = list(ctor = empty_dt_edit_order_ack, datetime_cols = character(0)),
  empty_dt_edit_preview = list(ctor = empty_dt_edit_preview, datetime_cols = character(0)),
  empty_dt_cancel_results = list(ctor = empty_dt_cancel_results, datetime_cols = character(0)),
  empty_dt_margin_window = list(ctor = empty_dt_margin_window, datetime_cols = "end_time"),
  empty_dt_futures_balance = list(ctor = empty_dt_futures_balance, datetime_cols = character(0)),
  empty_dt_futures_positions = list(ctor = empty_dt_futures_positions, datetime_cols = "expiration_time"),
  empty_dt_futures_sweeps = list(ctor = empty_dt_futures_sweeps, datetime_cols = "timestamp"),
  empty_dt_stats = list(ctor = empty_dt_stats, datetime_cols = character(0)),
  empty_dt_product_stats = list(ctor = empty_dt_product_stats, datetime_cols = character(0)),
  empty_dt_best_bid_ask = list(ctor = empty_dt_best_bid_ask, datetime_cols = "timestamp"),
  empty_dt_portfolio_summary = list(ctor = empty_dt_portfolio_summary, datetime_cols = character(0))
)

test_that("every empty_dt_* constructor returns a zero-row, fully-typed, list-column-free table", {
  for (nm in names(empty_constructors)) {
    dt <- empty_constructors[[nm]]$ctor()
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L, label = nm)
    expect_true(ncol(dt) > 0L, label = paste(nm, "column count"))
    expect_false(any(vapply(dt, is.list, logical(1L))), label = paste(nm, "list column"))
  }
})

test_that("empty_dt_* datetime columns are POSIXct, matching their populated branch", {
  for (nm in names(empty_constructors)) {
    dt <- empty_constructors[[nm]]$ctor()
    for (col in empty_constructors[[nm]]$datetime_cols) {
      expect_true(col %in% names(dt), label = paste(nm, col, "present"))
      expect_s3_class(dt[[col]], "POSIXct")
    }
  }
})

test_that("every fixed-shape parser returns its typed empty on NULL/empty input", {
  # (parser, empty input) for each fixed-shape endpoint parser. The bulk-stats
  # parser keys off a named list; the rest take a NULL or empty list.
  cases <- list(
    parse_products = list(parse_products, NULL),
    parse_candles = list(parse_candles, NULL),
    parse_trades = list(parse_trades, NULL),
    parse_accounts = list(parse_accounts, NULL),
    parse_fees = list(parse_fees, NULL),
    parse_orders = list(parse_orders, NULL),
    parse_fills = list(parse_fills, NULL),
    parse_preview = list(parse_preview, NULL),
    parse_cancel_results = list(parse_cancel_results, NULL),
    parse_margin_window = list(parse_margin_window, NULL),
    parse_futures_balance = list(parse_futures_balance, NULL),
    parse_futures_positions = list(parse_futures_positions, NULL),
    parse_futures_sweeps = list(parse_futures_sweeps, NULL),
    parse_stats = list(parse_stats, NULL),
    parse_product_stats = list(parse_product_stats, NULL),
    parse_best_bid_ask = list(parse_best_bid_ask, NULL)
  )

  for (nm in names(cases)) {
    parser <- cases[[nm]][[1L]]
    dt <- parser(cases[[nm]][[2L]])
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L, label = nm)
    expect_true(ncol(dt) > 0L, label = paste(nm, "column count"))
    expect_false(any(vapply(dt, is.list, logical(1L))), label = paste(nm, "list column"))
  }
})
