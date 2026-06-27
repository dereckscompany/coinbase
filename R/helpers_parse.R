# File: R/helpers_parse.R
# Response parsing and data.table construction helpers.

#' Return `x`, or `default` When `x` Is NULL
#'
#' A plainly-named, readable null-coalescing helper: it initialises with the
#' default and updates only when `x` is present. Used for the many inline field
#' defaults where an init-then-update statement cannot be written (i.e. inside a
#' `data.table()` call).
#'
#' @param x (any | NULL) a value or NULL.
#' @param default (any) the value to use when `x` is NULL.
#' @return (any) `x` when it is non-NULL, otherwise `default`.
#'
#' @keywords internal
#' @noRd
coalesce_null <- function(x, default) {
  assert_args_coalesce_null(x, default)
  result <- default
  if (!is.null(x)) {
    result <- x
  }
  return(assert_return_coalesce_null(result))
}

#' Coerce a Possibly-NULL Scalar to Numeric
#'
#' @param x (any | NULL) a numeric-coercible scalar (the raw JSON value, whose R
#'   type is unconstrained: integer, double, character, or logical), or NULL.
#' @return (scalar<numeric | NA>) `as.numeric(x)`, or `NA_real_` if `x` is NULL.
#'
#' @keywords internal
#' @noRd
num_or_na <- function(x) {
  assert_args_num_or_na(x)
  result <- NA_real_
  if (!is.null(x)) {
    result <- as.numeric(x)
  }
  return(assert_return_num_or_na(result))
}

#' Coerce a Scalar or `{value, currency}` Object to Numeric
#'
#' Some Coinbase fields are plain numeric strings, others are nested
#' `{value, currency}` objects. This returns the numeric value either way.
#'
#' @param x (any | NULL) a numeric-coercible scalar (raw JSON value, R type
#'   unconstrained), a `{value, ...}` list, or NULL.
#' @return (scalar<numeric | NA>) the numeric value, or `NA_real_` if NULL.
#'
#' @keywords internal
#' @noRd
flex_num <- function(x) {
  assert_args_flex_num(x)
  result <- NA_real_
  if (is.list(x)) {
    result <- amount_value(x)
  } else if (!is.null(x)) {
    result <- as.numeric(x)
  }
  return(assert_return_flex_num(result))
}

#' Extract the Numeric `value` from a Coinbase `{value, currency}` Object
#'
#' Coinbase represents monetary amounts as nested `{value, currency}` objects.
#' This flattens one to its numeric `value`, avoiding list columns downstream.
#'
#' @param x (list | NULL) a list with a `value` field, or NULL.
#' @return (scalar<numeric | NA>) the numeric value, or `NA_real_` if `x` is NULL.
#'
#' @keywords internal
#' @noRd
amount_value <- function(x) {
  assert_args_amount_value(x)
  result <- NA_real_
  if (!is.null(x) && !is.null(x$value)) {
    result <- as.numeric(x$value)
  }
  return(assert_return_amount_value(result))
}

#' Coerce a Money Field (number, Amount, or BalancePair) to Numeric
#'
#' Coinbase expresses monetary fields three ways: a plain numeric string, an
#' `Amount` (`{value, currency}`), or a `BalancePair`
#' (`{userNativeCurrency, rawCurrency}`, each an `Amount`). This returns the
#' numeric value for any of them, preferring the user's native (display)
#' currency for a `BalancePair`. Used by the portfolio-breakdown parsers, where
#' spot uses `Amount` and perp uses `BalancePair`.
#'
#' @param x (any | NULL) a numeric-coercible scalar (raw JSON value, R type
#'   unconstrained), an `Amount`, a `BalancePair`, or NULL.
#' @return (scalar<numeric | NA>) the numeric value, or `NA_real_` when absent.
#'
#' @keywords internal
#' @noRd
money_value <- function(x) {
  assert_args_money_value(x)
  result <- NA_real_
  if (is.list(x)) {
    if (!is.null(x$value)) {
      result <- as.numeric(x$value)
    } else if (!is.null(x$userNativeCurrency) && !is.null(x$userNativeCurrency$value)) {
      result <- as.numeric(x$userNativeCurrency$value)
    } else if (!is.null(x$rawCurrency) && !is.null(x$rawCurrency$value)) {
      result <- as.numeric(x$rawCurrency$value)
    }
  } else if (!is.null(x)) {
    result <- as.numeric(x)
  }
  return(assert_return_money_value(result))
}

#' Safely Read the i-th Element of a Positional Array as Numeric
#'
#' Coinbase returns candles and order-book levels as positional arrays. A short
#' or partial array would make `x[[i]]` raise a subscript error; this returns
#' `NA_real_` instead when the element is missing or NULL.
#'
#' @param x (list | vector<any, 0..> | NULL) a list/vector, or NULL.
#' @param i (scalar<count in [1, Inf[>) the element index.
#' @return (scalar<numeric | NA>) `as.numeric(x[[i]])`, or `NA_real_` when absent.
#'
#' @keywords internal
#' @noRd
nth_num <- function(x, i) {
  assert_args_nth_num(x, i)
  result <- NA_real_
  if (length(x) >= i && !is.null(x[[i]])) {
    result <- as.numeric(x[[i]])
  }
  return(assert_return_nth_num(result))
}

#' Safely Read the i-th Element of a Positional Array as Character
#'
#' @param x (list | vector<any, 0..> | NULL) a list/vector, or NULL.
#' @param i (scalar<count in [1, Inf[>) the element index.
#' @return (scalar<character | NA>) `as.character(x[[i]])`, or `NA_character_`
#'   when absent.
#'
#' @keywords internal
#' @noRd
nth_chr <- function(x, i) {
  assert_args_nth_chr(x, i)
  result <- NA_character_
  if (length(x) >= i && !is.null(x[[i]])) {
    result <- as.character(x[[i]])
  }
  return(assert_return_nth_chr(result))
}

#' Collapse a Coinbase Errors Array to a Single String
#'
#' Coinbase returns validation/preview/edit errors as an array whose elements are
#' usually objects but are sometimes bare strings. The reason lives under
#' different keys per endpoint — create orders use `error`/`error_details`/
#' `new_order_failure_reason`/`preview_failure_reason`; edits use
#' `edit_failure_reason`/`preview_failure_reason`/`edit_order_failure_reason`. We
#' look each up by its exact name (treating empty strings as missing) and flatten
#' the array to one human-readable string so it can live in a scalar column
#' rather than a list column.
#'
#' @param errs (list | NULL) a list of error objects/strings, or NULL.
#' @return (scalar<character | NA>) a single character string, or `NA_character_`
#'   if there are no errors.
#'
#' @keywords internal
#' @noRd
collapse_errors <- function(errs) {
  assert_args_collapse_errors(errs)
  if (is.null(errs) || length(errs) == 0) {
    return(assert_return_collapse_errors(NA_character_))
  }
  # The reason may live under any of these keys depending on the endpoint;
  # take the first non-empty one. Empty strings count as missing.
  keys <- c(
    "error_code",
    "edit_failure_reason",
    "preview_failure_reason",
    "edit_order_failure_reason",
    "new_order_failure_reason",
    "failure_reason",
    "error",
    "message",
    "reason",
    "error_details"
  )
  parts <- vapply(
    errs,
    function(e) {
      if (!is.list(e)) {
        return(as.character(e))
      }
      for (key in keys) {
        cand <- e[[key]]
        if (!is.null(cand) && nzchar(as.character(cand)[1])) {
          return(as.character(cand)[1])
        }
      }
      return(NA_character_)
    },
    character(1)
  )
  parts <- parts[!is.na(parts) & nzchar(parts)]
  if (length(parts) == 0) {
    return(assert_return_collapse_errors(NA_character_))
  }
  return(assert_return_collapse_errors(paste(parts, collapse = "; ")))
}

#' Convert camelCase Names to snake_case
#'
#' Converts response field names to R's snake_case convention. Coinbase fields
#' are predominantly snake_case already, so this is largely a pass-through; it
#' exists to guarantee the convention holds for any camelCase outliers.
#'
#' @param names (character) names to convert.
#' @return (character) converted snake_case names.
#'
#' @keywords internal
#' @noRd
to_snake_case <- function(names) {
  assert_args_to_snake_case(names)
  out <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", names)
  out <- gsub("([A-Z])([A-Z][a-z])", "\\1_\\2", out)
  out <- tolower(out)
  return(assert_return_to_snake_case(out))
}

#' Convert a Named List to a Single-Row data.table
#'
#' Converts a flat named list (from a Coinbase JSON object) into a single-row
#' [data.table::data.table]. NULL or empty values become NA. Any nested
#' object/array or multi-element value is collapsed to a single JSON string, so
#' the result is guaranteed to contain no list columns (and never row-recycles)
#' even if the API returns an unexpectedly nested field.
#'
#' @param x (list | NULL) a named list.
#' @return (class<data.table>) a single-row [data.table::data.table] with
#'   snake_case column names.
#'
#' @keywords internal
#' @noRd
as_dt_row <- function(x) {
  assert_args_as_dt_row(x)
  if (is.null(x) || length(x) == 0) {
    return(assert_return_as_dt_row(data.table::data.table()[]))
  }
  x <- lapply(x, function(val) {
    if (is.null(val)) {
      return(NA)
    }
    if (is.list(val) && length(val) == 0) {
      return(NA)
    }
    # Enforce the no-list-column contract: collapse any nested object/array or
    # multi-element value to a single JSON string rather than a list column.
    if (is.list(val) || length(val) != 1L) {
      return(as.character(jsonlite::toJSON(val, auto_unbox = TRUE, null = "null")))
    }
    return(val)
  })
  dt <- data.table::as.data.table(x)
  data.table::setnames(dt, to_snake_case(names(dt)))
  return(assert_return_as_dt_row(dt[]))
}

#' Convert a List of Named Lists to a data.table
#'
#' Row-binds a list whose elements are named lists (a JSON array of objects)
#' into a [data.table::data.table] with snake_case columns.
#'
#' @param items (list | NULL) a list of named lists, or NULL.
#' @return (class<data.table>) the row-bound table; empty if `items` is NULL or
#'   empty.
#'
#' @keywords internal
#' @noRd
as_dt_list <- function(items) {
  assert_args_as_dt_list(items)
  if (is.null(items) || length(items) == 0) {
    return(assert_return_as_dt_list(data.table::data.table()[]))
  }
  dt <- data.table::rbindlist(lapply(items, as_dt_row), fill = TRUE)
  return(assert_return_as_dt_list(dt[]))
}

# ---- Typed zero-row empties ------------------------------------------------
# Each fixed-shape parser's empty branch returns the fully-typed zero-row table
# for its shape (columns and types EXACTLY matching R/types_coinbase.R and the
# parser's non-empty branch) so a method's column contract still holds on an
# empty result. Datetime columns are built with the SAME helper the parser uses
# (iso_to_datetime / s_to_datetime on a zero-length vector) so class and tz
# match the populated case. These mirror their shape; they are deliberately not
# asserted.

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_ohlcv <- function() {
  return(data.table::data.table(
    datetime = s_to_datetime(numeric(0)),
    open = numeric(0),
    high = numeric(0),
    low = numeric(0),
    close = numeric(0),
    volume = numeric(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_trades <- function() {
  return(data.table::data.table(
    trade_id = numeric(0),
    side = character(0),
    price = numeric(0),
    size = numeric(0),
    time = iso_to_datetime(character(0))
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_accounts <- function() {
  return(data.table::data.table(
    uuid = character(0),
    name = character(0),
    currency = character(0),
    available_balance = numeric(0),
    hold = numeric(0),
    active = logical(0),
    default = logical(0),
    ready = logical(0),
    type = character(0),
    platform = character(0),
    retail_portfolio_id = character(0),
    created_at = iso_to_datetime(character(0)),
    updated_at = iso_to_datetime(character(0))
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_fees <- function() {
  return(data.table::data.table(
    pricing_tier = character(0),
    maker_fee_rate = numeric(0),
    taker_fee_rate = numeric(0),
    usd_from = numeric(0),
    usd_to = numeric(0),
    total_volume = numeric(0),
    total_fees = numeric(0),
    total_balance = numeric(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_orders <- function() {
  return(data.table::data.table(
    order_id = character(0),
    client_order_id = character(0),
    product_id = character(0),
    side = character(0),
    status = character(0),
    order_type = character(0),
    config_type = character(0),
    time_in_force = character(0),
    created_time = iso_to_datetime(character(0)),
    completion_percentage = numeric(0),
    filled_size = numeric(0),
    average_filled_price = numeric(0),
    number_of_fills = numeric(0),
    filled_value = numeric(0),
    total_fees = numeric(0),
    base_size = numeric(0),
    quote_size = numeric(0),
    limit_price = numeric(0),
    stop_price = numeric(0),
    stop_trigger_price = numeric(0),
    stop_direction = character(0),
    end_time = iso_to_datetime(character(0)),
    post_only = logical(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_fills <- function() {
  return(data.table::data.table(
    entry_id = character(0),
    trade_id = character(0),
    order_id = character(0),
    product_id = character(0),
    side = character(0),
    trade_time = iso_to_datetime(character(0)),
    trade_type = character(0),
    price = numeric(0),
    size = numeric(0),
    commission = numeric(0),
    size_in_quote = logical(0),
    liquidity_indicator = character(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_preview <- function() {
  return(data.table::data.table(
    order_total = numeric(0),
    commission_total = numeric(0),
    quote_size = numeric(0),
    base_size = numeric(0),
    best_bid = numeric(0),
    best_ask = numeric(0),
    slippage = numeric(0),
    errs = character(0),
    preview_id = character(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_create_order_ack <- function() {
  return(data.table::data.table(
    success = logical(0),
    order_id = character(0),
    product_id = character(0),
    side = character(0),
    client_order_id = character(0),
    failure_reason = character(0),
    config_type = character(0),
    base_size = numeric(0),
    quote_size = numeric(0),
    limit_price = numeric(0),
    stop_price = numeric(0),
    stop_trigger_price = numeric(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_edit_order_ack <- function() {
  return(data.table::data.table(
    success = logical(0),
    order_id = character(0),
    errors = character(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_edit_preview <- function() {
  return(data.table::data.table(
    errors = character(0),
    slippage = numeric(0),
    order_total = numeric(0),
    commission_total = numeric(0),
    quote_size = numeric(0),
    base_size = numeric(0),
    best_bid = numeric(0),
    average_filled_price = numeric(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_cancel_results <- function() {
  return(data.table::data.table(
    order_id = character(0),
    success = logical(0),
    failure_reason = character(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_margin_window <- function() {
  return(data.table::data.table(
    margin_window_type = character(0),
    end_time = iso_to_datetime(character(0)),
    is_intraday_margin_killswitch_enabled = logical(0),
    is_intraday_margin_enrollment_killswitch_enabled = logical(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_futures_balance <- function() {
  return(data.table::data.table(
    futures_buying_power = numeric(0),
    total_usd_balance = numeric(0),
    cbi_usd_balance = numeric(0),
    cfm_usd_balance = numeric(0),
    total_open_orders_hold_amount = numeric(0),
    unrealized_pnl = numeric(0),
    daily_realized_pnl = numeric(0),
    initial_margin = numeric(0),
    available_margin = numeric(0),
    liquidation_threshold = numeric(0),
    liquidation_buffer_amount = numeric(0),
    liquidation_buffer_percentage = numeric(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_futures_positions <- function() {
  return(data.table::data.table(
    product_id = character(0),
    side = character(0),
    number_of_contracts = numeric(0),
    current_price = numeric(0),
    avg_entry_price = numeric(0),
    unrealized_pnl = numeric(0),
    daily_realized_pnl = numeric(0),
    expiration_time = iso_to_datetime(character(0))
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_futures_sweeps <- function() {
  return(data.table::data.table(
    id = character(0),
    requested_amount = numeric(0),
    should_sweep_all = logical(0),
    status = character(0),
    schedule_time = iso_to_datetime(character(0))
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_stats <- function() {
  return(data.table::data.table(
    product_id = character(0),
    open = numeric(0),
    high = numeric(0),
    low = numeric(0),
    last = numeric(0),
    volume = numeric(0),
    volume_30day = numeric(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_product_stats <- function() {
  return(data.table::data.table(
    open = numeric(0),
    high = numeric(0),
    low = numeric(0),
    last = numeric(0),
    volume = numeric(0),
    volume_30day = numeric(0),
    rfq_volume_24hour = numeric(0),
    rfq_volume_30day = numeric(0),
    conversions_volume_24hour = numeric(0),
    conversions_volume_30day = numeric(0)
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_best_bid_ask <- function() {
  return(data.table::data.table(
    product_id = character(0),
    bid_price = numeric(0),
    bid_size = numeric(0),
    ask_price = numeric(0),
    ask_size = numeric(0),
    time = iso_to_datetime(character(0))
  ))
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_portfolio_summary <- function() {
  return(data.table::data.table(
    uuid = character(0),
    name = character(0),
    type = character(0),
    total_balance = numeric(0),
    total_futures_balance = numeric(0),
    total_cash_equivalent_balance = numeric(0),
    total_crypto_balance = numeric(0),
    futures_unrealized_pnl = numeric(0),
    perp_unrealized_pnl = numeric(0),
    total_equities_balance = numeric(0)
  ))
}

#' Parse Coinbase Exchange Candles into an OHLCV data.table
#'
#' The Exchange API returns each candle as the array
#' `[time, low, high, open, close, volume]` (time in epoch seconds), newest
#' first. This reorders to the canonical OHLCV layout and sorts ascending.
#'
#' @param data (list | NULL) a list of candle arrays, or NULL.
#' @return (class<data.table>) columns `datetime`, `open`, `high`, `low`,
#'   `close`, `volume`. Empty if `data` is NULL or empty.
#'
#' @keywords internal
#' @noRd
parse_candles <- function(data) {
  assert_args_parse_candles(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_candles(empty_dt_ohlcv()))
  }
  dt <- data.table::data.table(
    datetime = s_to_datetime(vapply(data, function(c) nth_num(c, 1L), numeric(1))),
    open = vapply(data, function(c) nth_num(c, 4L), numeric(1)),
    high = vapply(data, function(c) nth_num(c, 3L), numeric(1)),
    low = vapply(data, function(c) nth_num(c, 2L), numeric(1)),
    close = vapply(data, function(c) nth_num(c, 5L), numeric(1)),
    volume = vapply(data, function(c) nth_num(c, 6L), numeric(1))
  )
  data.table::setorder(dt, datetime)
  return(assert_return_parse_candles(dt[]))
}

#' Parse Coinbase Exchange Trades into a data.table
#'
#' @param data (list | NULL) a list of trade objects (`trade_id`, `side`,
#'   `size`, `price`, `time`), or NULL.
#' @return (class<data.table>) columns `trade_id`, `side`, `price`, `size`,
#'   `time`. Empty if `data` is NULL or empty.
#'
#' @keywords internal
#' @noRd
parse_trades <- function(data) {
  assert_args_parse_trades(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_trades(empty_dt_trades()))
  }
  dt <- data.table::data.table(
    trade_id = vapply(data, function(t) num_or_na(t$trade_id), numeric(1)),
    side = vapply(data, function(t) as.character(coalesce_null(t$side, NA_character_)), character(1)),
    price = vapply(data, function(t) num_or_na(t$price), numeric(1)),
    size = vapply(data, function(t) num_or_na(t$size), numeric(1)),
    time = iso_to_datetime(vapply(data, function(t) coalesce_null(t$time, NA_character_), character(1)))
  )
  return(assert_return_parse_trades(dt[]))
}

#' Parse Coinbase Trading Accounts into a data.table
#'
#' Flattens the nested `available_balance`/`hold` `{value, currency}` objects to
#' numeric columns and parses timestamps, yielding a list-column-free table.
#'
#' @param items (list | NULL) a list of account objects, or NULL.
#' @return (class<data.table>) one row per account. Empty if `items` is NULL or
#'   empty.
#'
#' @keywords internal
#' @noRd
parse_accounts <- function(items) {
  assert_args_parse_accounts(items)
  items <- Filter(Negate(is.null), coalesce_null(items, list()))
  if (length(items) == 0L) {
    return(assert_return_parse_accounts(empty_dt_accounts()))
  }
  rows <- lapply(items, function(a) {
    return(data.table::data.table(
      uuid = coalesce_null(a$uuid, NA_character_),
      name = coalesce_null(a$name, NA_character_),
      currency = coalesce_null(a$currency, NA_character_),
      available_balance = amount_value(a$available_balance),
      hold = amount_value(a$hold),
      active = coalesce_null(a$active, NA),
      default = coalesce_null(a$default, NA),
      ready = coalesce_null(a$ready, NA),
      type = coalesce_null(a$type, NA_character_),
      platform = coalesce_null(a$platform, NA_character_),
      retail_portfolio_id = coalesce_null(a$retail_portfolio_id, NA_character_),
      created_at = iso_to_datetime(coalesce_null(a$created_at, NA_character_)),
      updated_at = iso_to_datetime(coalesce_null(a$updated_at, NA_character_))
    ))
  })
  return(assert_return_parse_accounts(data.table::rbindlist(rows, fill = TRUE)[]))
}

#' Parse a Coinbase Transaction Summary into a one-row data.table
#'
#' Flattens the nested `fee_tier` object into scalar columns alongside the
#' top-level volume and fee fields.
#'
#' @param data (list | NULL) a transaction summary object, or NULL.
#' @return (class<data.table>) a single-row table. Empty if `data` is NULL.
#'
#' @keywords internal
#' @noRd
parse_fees <- function(data) {
  assert_args_parse_fees(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_fees(empty_dt_fees()))
  }
  ft <- coalesce_null(data$fee_tier, list())
  return(assert_return_parse_fees(data.table::data.table(
    pricing_tier = coalesce_null(ft$pricing_tier, NA_character_),
    maker_fee_rate = as.numeric(coalesce_null(ft$maker_fee_rate, NA)),
    taker_fee_rate = as.numeric(coalesce_null(ft$taker_fee_rate, NA)),
    usd_from = as.numeric(coalesce_null(ft$usd_from, NA)),
    usd_to = as.numeric(coalesce_null(ft$usd_to, NA)),
    total_volume = as.numeric(coalesce_null(data$total_volume, NA)),
    total_fees = as.numeric(coalesce_null(data$total_fees, NA)),
    total_balance = as.numeric(coalesce_null(data$total_balance, NA))
  )[]))
}

#' Flatten a Coinbase `order_configuration` Object
#'
#' The order configuration is keyed by the detailed order type (e.g.
#' `market_market_ioc`, `limit_limit_gtc`, `stop_limit_stop_limit_gtc`). This
#' returns the inner type key plus the union of recognised sub-fields, so an
#' order row carries scalar config columns rather than a nested list.
#'
#' @param cfg (list | NULL) a one-key `order_configuration` list, or NULL.
#' @return (list) the flattened config:
#' - config_type (scalar<character | NA>) the inner order-type key.
#' - base_size (scalar<numeric | NA>) base size.
#' - quote_size (scalar<numeric | NA>) quote size.
#' - limit_price (scalar<numeric | NA>) limit price.
#' - stop_price (scalar<numeric | NA>) stop price.
#' - stop_trigger_price (scalar<numeric | NA>) bracket trigger price.
#' - stop_direction (scalar<character | NA>) stop direction.
#' - end_time (scalar<POSIXct | NA>) good-till time.
#' - post_only (scalar<logical | NA>) post-only flag.
#'
#' @keywords internal
#' @noRd
flatten_order_config <- function(cfg) {
  assert_args_flatten_order_config(cfg)
  inner <- list()
  config_type <- NA_character_
  if (!is.null(cfg) && length(cfg) > 0) {
    config_type <- names(cfg)[1]
    inner <- cfg[[1]]
  }
  return(assert_return_flatten_order_config(list(
    config_type = config_type,
    base_size = num_or_na(inner$base_size),
    quote_size = num_or_na(inner$quote_size),
    limit_price = num_or_na(inner$limit_price),
    stop_price = num_or_na(inner$stop_price),
    # Bracket orders (trigger_bracket_*) carry the trigger here, not in stop_price.
    stop_trigger_price = num_or_na(inner$stop_trigger_price),
    stop_direction = coalesce_null(inner$stop_direction, NA_character_),
    end_time = iso_to_datetime(coalesce_null(inner$end_time, NA_character_)),
    post_only = coalesce_null(inner$post_only, NA)
  )))
}

#' Parse Coinbase Orders into a data.table
#'
#' Flattens each order's scalar fields and its nested `order_configuration` into
#' columns, yielding a list-column-free table.
#'
#' @param items (list | NULL) a list of order objects, or NULL.
#' @return (class<data.table>) one row per order. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_orders <- function(items) {
  assert_args_parse_orders(items)
  items <- Filter(Negate(is.null), coalesce_null(items, list()))
  if (length(items) == 0L) {
    return(assert_return_parse_orders(empty_dt_orders()))
  }
  rows <- lapply(items, function(o) {
    cfg <- flatten_order_config(o$order_configuration)
    return(data.table::data.table(
      order_id = coalesce_null(o$order_id, coalesce_null(o$id, NA_character_)),
      client_order_id = coalesce_null(o$client_order_id, NA_character_),
      product_id = coalesce_null(o$product_id, NA_character_),
      side = coalesce_null(o$side, NA_character_),
      status = coalesce_null(o$status, NA_character_),
      # The coarse API enum (e.g. "LIMIT"); the detailed key is `config_type`.
      order_type = coalesce_null(o$order_type, NA_character_),
      config_type = cfg$config_type,
      time_in_force = coalesce_null(o$time_in_force, NA_character_),
      created_time = iso_to_datetime(coalesce_null(o$created_time, NA_character_)),
      completion_percentage = num_or_na(o$completion_percentage),
      filled_size = num_or_na(o$filled_size),
      average_filled_price = num_or_na(o$average_filled_price),
      number_of_fills = num_or_na(o$number_of_fills),
      filled_value = num_or_na(o$filled_value),
      total_fees = num_or_na(o$total_fees),
      base_size = cfg$base_size,
      quote_size = cfg$quote_size,
      limit_price = cfg$limit_price,
      stop_price = cfg$stop_price,
      stop_trigger_price = cfg$stop_trigger_price,
      stop_direction = cfg$stop_direction,
      end_time = cfg$end_time,
      post_only = cfg$post_only
    ))
  })
  return(assert_return_parse_orders(data.table::rbindlist(rows, fill = TRUE)[]))
}

#' Parse Coinbase Fills into a data.table
#'
#' @param items (list | NULL) a list of fill objects, or NULL.
#' @return (class<data.table>) one row per fill. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_fills <- function(items) {
  assert_args_parse_fills(items)
  items <- Filter(Negate(is.null), coalesce_null(items, list()))
  if (length(items) == 0L) {
    return(assert_return_parse_fills(empty_dt_fills()))
  }
  rows <- lapply(items, function(f) {
    return(data.table::data.table(
      entry_id = coalesce_null(f$entry_id, NA_character_),
      trade_id = coalesce_null(f$trade_id, NA_character_),
      order_id = coalesce_null(f$order_id, NA_character_),
      product_id = coalesce_null(f$product_id, NA_character_),
      side = coalesce_null(f$side, NA_character_),
      trade_time = iso_to_datetime(coalesce_null(f$trade_time, NA_character_)),
      trade_type = coalesce_null(f$trade_type, NA_character_),
      price = num_or_na(f$price),
      size = num_or_na(f$size),
      commission = num_or_na(f$commission),
      size_in_quote = coalesce_null(f$size_in_quote, NA),
      liquidity_indicator = coalesce_null(f$liquidity_indicator, NA_character_)
    ))
  })
  return(assert_return_parse_fills(data.table::rbindlist(rows, fill = TRUE)[]))
}

#' Parse a Coinbase Order Preview into a one-row data.table
#'
#' @param data (list | NULL) a preview response object, or NULL.
#' @return (class<data.table>) a single-row table. Empty if NULL.
#'
#' @keywords internal
#' @noRd
parse_preview <- function(data) {
  assert_args_parse_preview(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_preview(empty_dt_preview()))
  }
  return(assert_return_parse_preview(data.table::data.table(
    order_total = num_or_na(data$order_total),
    commission_total = num_or_na(data$commission_total),
    quote_size = num_or_na(data$quote_size),
    base_size = num_or_na(data$base_size),
    best_bid = num_or_na(data$best_bid),
    best_ask = num_or_na(data$best_ask),
    slippage = num_or_na(data$slippage),
    errs = collapse_errors(data$errs),
    preview_id = coalesce_null(data$preview_id, NA_character_)
  )[]))
}

#' Parse a Coinbase Create-Order Response into a one-row data.table
#'
#' Surfaces the scalar `order_id` (from `success_response`), collapses the
#' failure/error objects to a string, and flattens `order_configuration` — so
#' the result has no list columns and a usable order id.
#'
#' @param data (list | NULL) a `CreateOrderResponse` object, or NULL.
#' @return (class<data.table>) a single-row table. Empty if NULL.
#'
#' @keywords internal
#' @noRd
parse_create_order <- function(data) {
  assert_args_parse_create_order(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_create_order(empty_dt_create_order_ack()))
  }
  sr <- coalesce_null(data$success_response, list())
  cfg <- flatten_order_config(data$order_configuration)
  errs <- collapse_errors(Filter(Negate(is.null), list(data$failure_reason, data$error_response)))
  return(assert_return_parse_create_order(data.table::data.table(
    success = coalesce_null(data$success, NA),
    order_id = coalesce_null(sr$order_id, coalesce_null(data$order_id, NA_character_)),
    product_id = coalesce_null(sr$product_id, NA_character_),
    side = coalesce_null(sr$side, NA_character_),
    client_order_id = coalesce_null(sr$client_order_id, NA_character_),
    failure_reason = errs,
    config_type = cfg$config_type,
    base_size = cfg$base_size,
    quote_size = cfg$quote_size,
    limit_price = cfg$limit_price,
    stop_price = cfg$stop_price,
    stop_trigger_price = cfg$stop_trigger_price
  )[]))
}

#' Parse a Coinbase Edit-Order Response into a one-row data.table
#'
#' @param data (list | NULL) an `EditOrderResponse` object, or NULL.
#' @return (class<data.table>) a single-row table. Empty if NULL.
#'
#' @keywords internal
#' @noRd
parse_edit_order <- function(data) {
  assert_args_parse_edit_order(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_edit_order(empty_dt_edit_order_ack()))
  }
  sr <- coalesce_null(data$success_response, list())
  err_items <- c(coalesce_null(data$errors, list()), Filter(Negate(is.null), list(data$error_response)))
  return(assert_return_parse_edit_order(data.table::data.table(
    success = coalesce_null(data$success, NA),
    order_id = coalesce_null(sr$order_id, NA_character_),
    errors = collapse_errors(err_items)
  )[]))
}

#' Parse a Coinbase Edit-Order Preview into a one-row data.table
#'
#' @param data (list | NULL) an `EditOrderPreviewResponse` object, or NULL.
#' @return (class<data.table>) a single-row table. Empty if NULL.
#'
#' @keywords internal
#' @noRd
parse_edit_preview <- function(data) {
  assert_args_parse_edit_preview(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_edit_preview(empty_dt_edit_preview()))
  }
  return(assert_return_parse_edit_preview(data.table::data.table(
    errors = collapse_errors(data$errors),
    slippage = num_or_na(data$slippage),
    order_total = num_or_na(data$order_total),
    commission_total = num_or_na(data$commission_total),
    quote_size = num_or_na(data$quote_size),
    base_size = num_or_na(data$base_size),
    best_bid = num_or_na(data$best_bid),
    average_filled_price = num_or_na(data$average_filled_price)
  )[]))
}

#' Parse Coinbase Batch-Cancel Results into a data.table
#'
#' @param items (list | NULL) a list of per-order cancel results, or NULL.
#' @return (class<data.table>) one row per order. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_cancel_results <- function(items) {
  assert_args_parse_cancel_results(items)
  items <- Filter(Negate(is.null), coalesce_null(items, list()))
  if (length(items) == 0L) {
    return(assert_return_parse_cancel_results(empty_dt_cancel_results()))
  }
  rows <- lapply(items, function(r) {
    fr <- r$failure_reason
    fr_str <- coalesce_null(fr, NA_character_)
    if (is.list(fr)) {
      fr_str <- collapse_errors(list(fr))
    }
    return(data.table::data.table(
      order_id = coalesce_null(r$order_id, NA_character_),
      success = coalesce_null(r$success, NA),
      failure_reason = fr_str
    ))
  })
  return(assert_return_parse_cancel_results(data.table::rbindlist(rows, fill = TRUE)[]))
}

#' Parse a Coinbase Current-Margin-Window Response into a one-row data.table
#'
#' Flattens the nested `margin_window` object into scalar columns.
#'
#' @param data (list | NULL) a `GetCurrentMarginWindowResponse` object, or NULL.
#' @return (class<data.table>) a single-row table. Empty if NULL.
#'
#' @keywords internal
#' @noRd
parse_margin_window <- function(data) {
  assert_args_parse_margin_window(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_margin_window(empty_dt_margin_window()))
  }
  mw <- coalesce_null(data$margin_window, list())
  return(assert_return_parse_margin_window(data.table::data.table(
    margin_window_type = coalesce_null(mw$margin_window_type, NA_character_),
    end_time = iso_to_datetime(coalesce_null(mw$end_time, NA_character_)),
    is_intraday_margin_killswitch_enabled = coalesce_null(data$is_intraday_margin_killswitch_enabled, NA),
    is_intraday_margin_enrollment_killswitch_enabled = coalesce_null(
      data$is_intraday_margin_enrollment_killswitch_enabled,
      NA
    )
  )[]))
}

#' Parse a Coinbase Futures (CFM) Balance Summary into a one-row data.table
#'
#' Flattens the nested `{value, currency}` amounts into numeric columns.
#'
#' @param data (list | NULL) a balance-summary object, or NULL.
#' @return (class<data.table>) a single-row table. Empty if NULL.
#'
#' @keywords internal
#' @noRd
parse_futures_balance <- function(data) {
  assert_args_parse_futures_balance(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_futures_balance(empty_dt_futures_balance()))
  }
  return(assert_return_parse_futures_balance(data.table::data.table(
    futures_buying_power = flex_num(data$futures_buying_power),
    total_usd_balance = flex_num(data$total_usd_balance),
    cbi_usd_balance = flex_num(data$cbi_usd_balance),
    cfm_usd_balance = flex_num(data$cfm_usd_balance),
    total_open_orders_hold_amount = flex_num(data$total_open_orders_hold_amount),
    unrealized_pnl = flex_num(data$unrealized_pnl),
    daily_realized_pnl = flex_num(data$daily_realized_pnl),
    initial_margin = flex_num(data$initial_margin),
    available_margin = flex_num(data$available_margin),
    liquidation_threshold = flex_num(data$liquidation_threshold),
    liquidation_buffer_amount = flex_num(data$liquidation_buffer_amount),
    liquidation_buffer_percentage = num_or_na(data$liquidation_buffer_percentage)
  )[]))
}

#' Parse Coinbase Futures (CFM) Positions into a data.table
#'
#' @param items (list | NULL) a list of position objects, or NULL.
#' @return (class<data.table>) one row per position. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_futures_positions <- function(items) {
  assert_args_parse_futures_positions(items)
  items <- Filter(Negate(is.null), coalesce_null(items, list()))
  if (length(items) == 0L) {
    return(assert_return_parse_futures_positions(empty_dt_futures_positions()))
  }
  rows <- lapply(items, function(p) {
    return(data.table::data.table(
      product_id = coalesce_null(p$product_id, NA_character_),
      side = coalesce_null(p$side, NA_character_),
      number_of_contracts = flex_num(p$number_of_contracts),
      current_price = flex_num(p$current_price),
      avg_entry_price = flex_num(p$avg_entry_price),
      unrealized_pnl = flex_num(p$unrealized_pnl),
      daily_realized_pnl = flex_num(p$daily_realized_pnl),
      expiration_time = iso_to_datetime(coalesce_null(p$expiration_time, NA_character_))
    ))
  })
  return(assert_return_parse_futures_positions(data.table::rbindlist(rows, fill = TRUE)[]))
}

#' Parse Coinbase Futures (CFM) Sweeps into a data.table
#'
#' @param items (list | NULL) a list of sweep objects, or NULL.
#' @return (class<data.table>) one row per sweep. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_futures_sweeps <- function(items) {
  assert_args_parse_futures_sweeps(items)
  if (is.null(items) || length(items) == 0) {
    return(assert_return_parse_futures_sweeps(empty_dt_futures_sweeps()))
  }
  rows <- lapply(items, function(s) {
    return(data.table::data.table(
      id = coalesce_null(s$id, NA_character_),
      requested_amount = flex_num(s$requested_amount),
      should_sweep_all = coalesce_null(s$should_sweep_all, NA),
      status = coalesce_null(s$status, NA_character_),
      schedule_time = iso_to_datetime(coalesce_null(s$schedule_time, NA_character_))
    ))
  })
  return(assert_return_parse_futures_sweeps(data.table::rbindlist(rows, fill = TRUE)[]))
}

#' Parse a Coinbase Exchange Order Book into a long data.table
#'
#' Flattens the `bids`/`asks` arrays into a single long table with a `side`
#' column. At levels 1 and 2 each entry is `[price, size, num_orders]`; at level
#' 3 the third element is an `order_id` string (the book is non-aggregated), so
#' the third column is emitted as `order_id` rather than coerced to numeric.
#'
#' @param data (list | NULL) a list with `bids` and `asks`, or NULL.
#' @param level (scalar<count in [1, 3]>) the requested book level (1, 2, or 3).
#'   Default 2.
#' @return (class<data.table>) columns `side`, `price`, `size`, and either
#'   `num_orders` (levels 1-2) or `order_id` (level 3). Empty if `data` is NULL
#'   or empty.
#'
#' @keywords internal
#' @noRd
parse_orderbook <- function(data, level = 2L) {
  assert_args_parse_orderbook(data, level)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_orderbook(data.table::data.table()[]))
  }
  is_l3 <- isTRUE(as.integer(level) == 3L)
  one_side <- function(levels, side) {
    if (is.null(levels) || length(levels) == 0) {
      return(data.table::data.table()[])
    }
    dt <- data.table::data.table(
      side = side,
      price = vapply(levels, function(l) nth_num(l, 1L), numeric(1)),
      size = vapply(levels, function(l) nth_num(l, 2L), numeric(1))
    )
    if (is_l3) {
      dt[, order_id := vapply(levels, function(l) nth_chr(l, 3L), character(1))]
    } else {
      dt[, num_orders := vapply(levels, function(l) nth_num(l, 3L), numeric(1))]
    }
    return(dt[])
  }
  dt <- data.table::rbindlist(
    list(one_side(data$bids, "bid"), one_side(data$asks, "ask")),
    fill = TRUE
  )
  return(assert_return_parse_orderbook(dt[]))
}

#' Parse the Coinbase Exchange Bulk Product Stats into a data.table
#'
#' The bulk `/products/stats` endpoint returns an object keyed by product id,
#' each value carrying `stats_24hour` and `stats_30day` sub-objects. This
#' flattens it to one row per product with numeric 24h OHLCV plus 30-day volume
#' -- the basis for a movers/most-active scanner.
#'
#' @param data (list | NULL) a named list keyed by product id, or NULL.
#' @return (class<data.table>) one row per product. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_stats <- function(data) {
  assert_args_parse_stats(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_stats(empty_dt_stats()))
  }
  ids <- names(data)
  rows <- lapply(ids, function(pid) {
    s <- data[[pid]]
    d24 <- coalesce_null(s$stats_24hour, list())
    d30 <- coalesce_null(s$stats_30day, list())
    return(data.table::data.table(
      product_id = pid,
      open = num_or_na(d24$open),
      high = num_or_na(d24$high),
      low = num_or_na(d24$low),
      last = num_or_na(d24$last),
      volume = num_or_na(d24$volume),
      volume_30day = num_or_na(d30$volume)
    ))
  })
  return(assert_return_parse_stats(data.table::rbindlist(rows, fill = TRUE)[]))
}

#' Parse a Coinbase Exchange Single-Product Stats Object into a one-row data.table
#'
#' @param data (list | NULL) a `/products/{id}/stats` object, or NULL.
#' @return (class<data.table>) a single-row table. Empty if NULL.
#'
#' @keywords internal
#' @noRd
parse_product_stats <- function(data) {
  assert_args_parse_product_stats(data)
  if (is.null(data) || length(data) == 0) {
    return(assert_return_parse_product_stats(empty_dt_product_stats()))
  }
  return(assert_return_parse_product_stats(data.table::data.table(
    open = num_or_na(data$open),
    high = num_or_na(data$high),
    low = num_or_na(data$low),
    last = num_or_na(data$last),
    volume = num_or_na(data$volume),
    volume_30day = num_or_na(data$volume_30day),
    rfq_volume_24hour = num_or_na(data$rfq_volume_24hour),
    rfq_volume_30day = num_or_na(data$rfq_volume_30day),
    conversions_volume_24hour = num_or_na(data$conversions_volume_24hour),
    conversions_volume_30day = num_or_na(data$conversions_volume_30day)
  )[]))
}

#' Parse a Coinbase Advanced Trade Best-Bid/Ask Response into a data.table
#'
#' Flattens the `pricebooks` array to one row per product carrying the best
#' (first) bid and ask price/size, avoiding list columns.
#'
#' @param data (list | NULL) a `GetBestBidAskResponse` object with a `pricebooks`
#'   array, or NULL.
#' @return (class<data.table>) one row per product. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_best_bid_ask <- function(data) {
  assert_args_parse_best_bid_ask(data)
  items <- Filter(Negate(is.null), coalesce_null(data$pricebooks, list()))
  if (length(items) == 0L) {
    return(assert_return_parse_best_bid_ask(empty_dt_best_bid_ask()))
  }
  rows <- lapply(items, function(pb) {
    bid <- list()
    if (length(pb$bids) > 0L) {
      bid <- pb$bids[[1L]]
    }
    ask <- list()
    if (length(pb$asks) > 0L) {
      ask <- pb$asks[[1L]]
    }
    return(data.table::data.table(
      product_id = coalesce_null(pb$product_id, NA_character_),
      bid_price = num_or_na(bid$price),
      bid_size = num_or_na(bid$size),
      ask_price = num_or_na(ask$price),
      ask_size = num_or_na(ask$size),
      time = iso_to_datetime(coalesce_null(pb$time, NA_character_))
    ))
  })
  return(assert_return_parse_best_bid_ask(data.table::rbindlist(rows, fill = TRUE)[]))
}

#' Parse a Coinbase Portfolio Breakdown into a stacked positions data.table
#'
#' The breakdown response nests three position arrays (spot, futures, perp) that
#' the live API returns with genuinely different shapes. They are flattened into
#' one [data.table::data.table], one row per holding, tagged by a `position_type`
#' discriminator column and combined with `fill = TRUE` (the same convention the
#' sibling packages use: kucoin's `account_type`, alpaca's `asset_class`). The
#' three concepts shared across types are normalised to common columns
#' (`entry_price`, `mark_price`, `side`, `unrealized_pnl`); the rest keep their
#' real API names. The portfolio's aggregate totals are returned separately by
#' [parse_portfolio_summary()] rather than attached as an attribute.
#'
#' @param data (list | NULL) a `GetPortfolioBreakdownResponse` object with a
#'   `breakdown` field, or NULL.
#' @return (class<data.table>) the positions. Empty if there are none.
#'
#' @keywords internal
#' @noRd
parse_portfolio_breakdown <- function(data) {
  assert_args_parse_portfolio_breakdown(data)
  bd <- coalesce_null(data$breakdown, list())

  spot_row <- function(p) {
    return(data.table::data.table(
      position_type = "spot",
      asset = coalesce_null(p$asset, NA_character_),
      side = NA_character_,
      entry_price = money_value(p$average_entry_price),
      mark_price = NA_real_,
      unrealized_pnl = num_or_na(p$unrealized_pnl),
      total_balance_crypto = num_or_na(p$total_balance_crypto),
      total_balance_fiat = num_or_na(p$total_balance_fiat),
      available_to_trade_crypto = num_or_na(p$available_to_trade_crypto),
      cost_basis = money_value(p$cost_basis),
      allocation = num_or_na(p$allocation),
      is_cash = coalesce_null(p$is_cash, NA),
      account_uuid = coalesce_null(p$account_uuid, NA_character_)
    ))
  }

  futures_row <- function(p) {
    return(data.table::data.table(
      position_type = "futures",
      product_id = coalesce_null(p$product_id, NA_character_),
      side = coalesce_null(p$side, NA_character_),
      entry_price = num_or_na(p$avg_entry_price),
      mark_price = num_or_na(p$current_price),
      unrealized_pnl = num_or_na(p$unrealized_pnl),
      amount = num_or_na(p$amount),
      contract_size = num_or_na(p$contract_size),
      notional_value = num_or_na(p$notional_value),
      expiry = iso_to_datetime(coalesce_null(p$expiry, NA_character_)),
      underlying_asset = coalesce_null(p$underlying_asset, NA_character_),
      venue = coalesce_null(p$venue, NA_character_)
    ))
  }

  perp_row <- function(p) {
    return(data.table::data.table(
      position_type = "perp",
      product_id = coalesce_null(p$product_id, NA_character_),
      symbol = coalesce_null(p$symbol, NA_character_),
      side = coalesce_null(p$position_side, NA_character_),
      entry_price = money_value(p$vwap),
      mark_price = money_value(p$mark_price),
      unrealized_pnl = money_value(p$unrealized_pnl),
      net_size = num_or_na(p$net_size),
      leverage = num_or_na(p$leverage),
      liquidation_price = money_value(p$liquidation_price),
      margin_type = coalesce_null(p$margin_type, NA_character_)
    ))
  }

  read_type <- function(items, reader) {
    items <- Filter(Negate(is.null), coalesce_null(items, list()))
    if (length(items) == 0L) {
      return(NULL)
    }
    return(data.table::rbindlist(lapply(items, reader), fill = TRUE))
  }

  parts <- Filter(
    Negate(is.null),
    list(
      read_type(bd$spot_positions, spot_row),
      read_type(bd$futures_positions, futures_row),
      read_type(bd$perp_positions, perp_row)
    )
  )
  positions <- data.table::data.table()
  if (length(parts) > 0L) {
    positions <- data.table::rbindlist(parts, fill = TRUE)
  }
  return(assert_return_parse_portfolio_breakdown(positions[]))
}

#' Parse a Coinbase Portfolio Breakdown's Aggregate Totals into a one-row data.table
#'
#' Reads the portfolio meta and `portfolio_balances` block from the breakdown
#' response. This is the summary companion to [parse_portfolio_breakdown()];
#' both parse the same endpoint, returning the totals and the positions
#' respectively, so each remains a single flat data.table.
#'
#' @param data (list | NULL) a `GetPortfolioBreakdownResponse` object with a
#'   `breakdown` field, or NULL.
#' @return (class<data.table>) a single-row table of portfolio totals.
#'
#' @keywords internal
#' @noRd
parse_portfolio_summary <- function(data) {
  assert_args_parse_portfolio_summary(data)
  bd <- coalesce_null(data$breakdown, list())
  p <- coalesce_null(bd$portfolio, list())
  b <- coalesce_null(bd$portfolio_balances, list())
  return(assert_return_parse_portfolio_summary(data.table::data.table(
    uuid = coalesce_null(p$uuid, NA_character_),
    name = coalesce_null(p$name, NA_character_),
    type = coalesce_null(p$type, NA_character_),
    total_balance = money_value(b$total_balance),
    total_futures_balance = money_value(b$total_futures_balance),
    total_cash_equivalent_balance = money_value(b$total_cash_equivalent_balance),
    total_crypto_balance = money_value(b$total_crypto_balance),
    futures_unrealized_pnl = money_value(b$futures_unrealized_pnl),
    perp_unrealized_pnl = money_value(b$perp_unrealized_pnl),
    total_equities_balance = money_value(b$total_equities_balance)
  )))
}
