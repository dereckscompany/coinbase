# File: R/helpers_parse.R
# Response parsing and data.table construction helpers.

#' Null-Coalesce Helper
#'
#' Returns `default` when `x` is NULL, otherwise `x`.
#'
#' @keywords internal
#' @noRd
`%or%` <- function(x, default) {
  if (is.null(x)) {
    return(default)
  }
  return(x)
}

#' Coerce a Possibly-NULL Scalar to Numeric
#'
#' @param x A scalar or NULL.
#' @return `as.numeric(x)`, or `NA_real_` if `x` is NULL.
#'
#' @keywords internal
#' @noRd
num_or_na <- function(x) {
  if (is.null(x)) {
    return(NA_real_)
  }
  return(as.numeric(x))
}

#' Coerce a Scalar or `{value, currency}` Object to Numeric
#'
#' Some Coinbase fields are plain numeric strings, others are nested
#' `{value, currency}` objects. This returns the numeric value either way.
#'
#' @param x A scalar, a `{value, ...}` list, or NULL.
#' @return Numeric scalar, or `NA_real_` if NULL.
#'
#' @keywords internal
#' @noRd
flex_num <- function(x) {
  if (is.null(x)) {
    return(NA_real_)
  }
  if (is.list(x)) {
    return(amount_value(x))
  }
  return(as.numeric(x))
}

#' Extract the Numeric `value` from a Coinbase `{value, currency}` Object
#'
#' Coinbase represents monetary amounts as nested `{value, currency}` objects.
#' This flattens one to its numeric `value`, avoiding list columns downstream.
#'
#' @param x A list with a `value` field, or NULL.
#' @return Numeric scalar, or `NA_real_` if `x` is NULL.
#'
#' @keywords internal
#' @noRd
amount_value <- function(x) {
  if (is.null(x) || is.null(x$value)) {
    return(NA_real_)
  }
  return(as.numeric(x$value))
}

#' Convert camelCase Names to snake_case
#'
#' Converts response field names to R's snake_case convention. Coinbase fields
#' are predominantly snake_case already, so this is largely a pass-through; it
#' exists to guarantee the convention holds for any camelCase outliers.
#'
#' @param names Character vector; names to convert.
#' @return Character vector; converted snake_case names.
#'
#' @keywords internal
#' @noRd
to_snake_case <- function(names) {
  out <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", names)
  out <- gsub("([A-Z])([A-Z][a-z])", "\\1_\\2", out)
  out <- tolower(out)
  return(out)
}

#' Convert a Named List to a Single-Row data.table
#'
#' Converts a flat named list (from a Coinbase JSON object) into a single-row
#' [data.table::data.table]. NULL values become NA. Nested lists of length >= 1
#' are wrapped so data.table stores them as a single list-column entry rather
#' than recycling rows; callers that must avoid list columns flatten such fields
#' explicitly before calling this.
#'
#' @param x A named list.
#' @return A single-row [data.table::data.table] with snake_case column names.
#'
#' @keywords internal
#' @noRd
as_dt_row <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(data.table::data.table()[])
  }
  x <- lapply(x, function(val) {
    if (is.null(val)) {
      return(NA)
    }
    if (is.list(val) && length(val) == 0) {
      return(NA)
    }
    if (is.list(val) && length(val) >= 1) {
      return(list(val))
    }
    return(val)
  })
  dt <- data.table::as.data.table(x)
  data.table::setnames(dt, to_snake_case(names(dt)))
  return(dt[])
}

#' Convert a List of Named Lists to a data.table
#'
#' Row-binds a list whose elements are named lists (a JSON array of objects)
#' into a [data.table::data.table] with snake_case columns.
#'
#' @param items A list of named lists, or NULL.
#' @return A [data.table::data.table]; empty if `items` is NULL or empty.
#'
#' @keywords internal
#' @noRd
as_dt_list <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  dt <- data.table::rbindlist(lapply(items, as_dt_row), fill = TRUE)
  return(dt[])
}

#' Parse Coinbase Exchange Candles into an OHLCV data.table
#'
#' The Exchange API returns each candle as the array
#' `[time, low, high, open, close, volume]` (time in epoch seconds), newest
#' first. This reorders to the canonical OHLCV layout and sorts ascending.
#'
#' @param data A list of candle arrays, or NULL.
#' @return A [data.table::data.table] with columns `datetime`, `open`, `high`,
#'   `low`, `close`, `volume`. Empty if `data` is NULL or empty.
#'
#' @keywords internal
#' @noRd
parse_candles <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  dt <- data.table::data.table(
    datetime = s_to_datetime(vapply(data, function(c) as.numeric(c[[1L]]), numeric(1))),
    open = vapply(data, function(c) as.numeric(c[[4L]]), numeric(1)),
    high = vapply(data, function(c) as.numeric(c[[3L]]), numeric(1)),
    low = vapply(data, function(c) as.numeric(c[[2L]]), numeric(1)),
    close = vapply(data, function(c) as.numeric(c[[5L]]), numeric(1)),
    volume = vapply(data, function(c) as.numeric(c[[6L]]), numeric(1))
  )
  data.table::setorder(dt, datetime)
  return(dt[])
}

#' Parse Coinbase Exchange Trades into a data.table
#'
#' @param data A list of trade objects (`trade_id`, `side`, `size`, `price`,
#'   `time`), or NULL.
#' @return A [data.table::data.table] with columns `trade_id`, `side`, `price`,
#'   `size`, `time`. Empty if `data` is NULL or empty.
#'
#' @keywords internal
#' @noRd
parse_trades <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  dt <- data.table::data.table(
    trade_id = vapply(data, function(t) as.numeric(t$trade_id), numeric(1)),
    side = vapply(data, function(t) as.character(t$side), character(1)),
    price = vapply(data, function(t) as.numeric(t$price), numeric(1)),
    size = vapply(data, function(t) as.numeric(t$size), numeric(1)),
    time = iso_to_datetime(vapply(data, function(t) as.character(t$time), character(1)))
  )
  return(dt[])
}

#' Parse Coinbase Trading Accounts into a data.table
#'
#' Flattens the nested `available_balance`/`hold` `{value, currency}` objects to
#' numeric columns and parses timestamps, yielding a list-column-free table.
#'
#' @param items A list of account objects, or NULL.
#' @return A [data.table::data.table] with one row per account. Empty if `items`
#'   is NULL or empty.
#'
#' @keywords internal
#' @noRd
parse_accounts <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(a) {
    return(data.table::data.table(
      uuid = a$uuid %or% NA_character_,
      name = a$name %or% NA_character_,
      currency = a$currency %or% NA_character_,
      available_balance = amount_value(a$available_balance),
      hold = amount_value(a$hold),
      active = a$active %or% NA,
      default = a$default %or% NA,
      ready = a$ready %or% NA,
      type = a$type %or% NA_character_,
      platform = a$platform %or% NA_character_,
      retail_portfolio_id = a$retail_portfolio_id %or% NA_character_,
      created_at = iso_to_datetime(a$created_at %or% NA_character_),
      updated_at = iso_to_datetime(a$updated_at %or% NA_character_)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a Coinbase Transaction Summary into a one-row data.table
#'
#' Flattens the nested `fee_tier` object into scalar columns alongside the
#' top-level volume and fee fields.
#'
#' @param data A transaction summary object, or NULL.
#' @return A single-row [data.table::data.table]. Empty if `data` is NULL.
#'
#' @keywords internal
#' @noRd
parse_fees <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  ft <- data$fee_tier %or% list()
  return(data.table::data.table(
    pricing_tier = ft$pricing_tier %or% NA_character_,
    maker_fee_rate = as.numeric(ft$maker_fee_rate %or% NA),
    taker_fee_rate = as.numeric(ft$taker_fee_rate %or% NA),
    usd_from = as.numeric(ft$usd_from %or% NA),
    usd_to = as.numeric(ft$usd_to %or% NA),
    total_volume = as.numeric(data$total_volume %or% NA),
    total_fees = as.numeric(data$total_fees %or% NA),
    total_balance = as.numeric(data$total_balance %or% NA)
  )[])
}

#' Flatten a Coinbase `order_configuration` Object
#'
#' The order configuration is keyed by the detailed order type (e.g.
#' `market_market_ioc`, `limit_limit_gtc`, `stop_limit_stop_limit_gtc`). This
#' returns the inner type key plus the union of recognised sub-fields, so an
#' order row carries scalar config columns rather than a nested list.
#'
#' @param cfg A one-key `order_configuration` list, or NULL.
#' @return Named list: `config_type`, `base_size`, `quote_size`, `limit_price`,
#'   `stop_price`, `stop_direction`, `end_time`, `post_only`.
#'
#' @keywords internal
#' @noRd
flatten_order_config <- function(cfg) {
  inner <- list()
  config_type <- NA_character_
  if (!is.null(cfg) && length(cfg) > 0) {
    config_type <- names(cfg)[1]
    inner <- cfg[[1]]
  }
  return(list(
    config_type = config_type,
    base_size = num_or_na(inner$base_size),
    quote_size = num_or_na(inner$quote_size),
    limit_price = num_or_na(inner$limit_price),
    stop_price = num_or_na(inner$stop_price),
    stop_direction = inner$stop_direction %or% NA_character_,
    end_time = iso_to_datetime(inner$end_time %or% NA_character_),
    post_only = inner$post_only %or% NA
  ))
}

#' Parse Coinbase Orders into a data.table
#'
#' Flattens each order's scalar fields and its nested `order_configuration` into
#' columns, yielding a list-column-free table.
#'
#' @param items A list of order objects, or NULL.
#' @return A [data.table::data.table], one row per order. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_orders <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(o) {
    cfg <- flatten_order_config(o$order_configuration)
    return(data.table::data.table(
      order_id = o$order_id %or% (o$id %or% NA_character_),
      client_order_id = o$client_order_id %or% NA_character_,
      product_id = o$product_id %or% NA_character_,
      side = o$side %or% NA_character_,
      status = o$status %or% NA_character_,
      order_type = o$order_type %or% cfg$config_type,
      config_type = cfg$config_type,
      time_in_force = o$time_in_force %or% NA_character_,
      created_time = iso_to_datetime(o$created_time %or% NA_character_),
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
      stop_direction = cfg$stop_direction,
      end_time = cfg$end_time,
      post_only = cfg$post_only
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse Coinbase Fills into a data.table
#'
#' @param items A list of fill objects, or NULL.
#' @return A [data.table::data.table], one row per fill. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_fills <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(f) {
    return(data.table::data.table(
      entry_id = f$entry_id %or% NA_character_,
      trade_id = f$trade_id %or% NA_character_,
      order_id = f$order_id %or% NA_character_,
      product_id = f$product_id %or% NA_character_,
      side = f$side %or% NA_character_,
      trade_time = iso_to_datetime(f$trade_time %or% NA_character_),
      trade_type = f$trade_type %or% NA_character_,
      price = num_or_na(f$price),
      size = num_or_na(f$size),
      commission = num_or_na(f$commission),
      size_in_quote = f$size_in_quote %or% NA,
      liquidity_indicator = f$liquidity_indicator %or% NA_character_
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a Coinbase Order Preview into a one-row data.table
#'
#' @param data A preview response object, or NULL.
#' @return A single-row [data.table::data.table]. Empty if NULL.
#'
#' @keywords internal
#' @noRd
parse_preview <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  errs <- data$errs
  err_str <- if (is.null(errs) || length(errs) == 0) NA_character_ else paste(unlist(errs), collapse = "; ")
  return(data.table::data.table(
    order_total = num_or_na(data$order_total),
    commission_total = num_or_na(data$commission_total),
    quote_size = num_or_na(data$quote_size),
    base_size = num_or_na(data$base_size),
    best_bid = num_or_na(data$best_bid),
    best_ask = num_or_na(data$best_ask),
    slippage = num_or_na(data$slippage),
    errs = err_str,
    preview_id = data$preview_id %or% NA_character_
  )[])
}

#' Parse a Coinbase Futures (CFM) Balance Summary into a one-row data.table
#'
#' Flattens the nested `{value, currency}` amounts into numeric columns.
#'
#' @param data A balance-summary object, or NULL.
#' @return A single-row [data.table::data.table]. Empty if NULL.
#'
#' @keywords internal
#' @noRd
parse_futures_balance <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  return(data.table::data.table(
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
  )[])
}

#' Parse Coinbase Futures (CFM) Positions into a data.table
#'
#' @param items A list of position objects, or NULL.
#' @return A [data.table::data.table], one row per position. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_futures_positions <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(p) {
    return(data.table::data.table(
      product_id = p$product_id %or% NA_character_,
      side = p$side %or% NA_character_,
      number_of_contracts = flex_num(p$number_of_contracts),
      current_price = flex_num(p$current_price),
      avg_entry_price = flex_num(p$avg_entry_price),
      unrealized_pnl = flex_num(p$unrealized_pnl),
      daily_realized_pnl = flex_num(p$daily_realized_pnl),
      expiration_time = iso_to_datetime(p$expiration_time %or% NA_character_)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse Coinbase Futures (CFM) Sweeps into a data.table
#'
#' @param items A list of sweep objects, or NULL.
#' @return A [data.table::data.table], one row per sweep. Empty if NULL/empty.
#'
#' @keywords internal
#' @noRd
parse_futures_sweeps <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(s) {
    return(data.table::data.table(
      id = s$id %or% NA_character_,
      requested_amount = flex_num(s$requested_amount),
      should_sweep_all = s$should_sweep_all %or% NA,
      status = s$status %or% NA_character_,
      schedule_time = iso_to_datetime(s$schedule_time %or% NA_character_)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a Coinbase Exchange Order Book into a long data.table
#'
#' Flattens the `bids`/`asks` arrays (each entry `[price, size, num_orders]`)
#' into a single long table with a `side` column, avoiding any list columns.
#'
#' @param data A list with `bids` and `asks`, or NULL.
#' @return A [data.table::data.table] with columns `side`, `price`, `size`,
#'   `num_orders`. Empty if `data` is NULL or empty.
#'
#' @keywords internal
#' @noRd
parse_orderbook <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  one_side <- function(levels, side) {
    if (is.null(levels) || length(levels) == 0) {
      return(data.table::data.table()[])
    }
    return(data.table::data.table(
      side = side,
      price = vapply(levels, function(l) as.numeric(l[[1L]]), numeric(1)),
      size = vapply(levels, function(l) as.numeric(l[[2L]]), numeric(1)),
      num_orders = vapply(levels, function(l) as.numeric(l[[3L]]), numeric(1))
    ))
  }
  dt <- data.table::rbindlist(
    list(one_side(data$bids, "bid"), one_side(data$asks, "ask")),
    fill = TRUE
  )
  return(dt[])
}
