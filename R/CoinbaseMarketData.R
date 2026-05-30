# File: R/CoinbaseMarketData.R
# Public market-data client for Coinbase. Uses the Exchange host
# (api.exchange.coinbase.com), whose endpoints require no authentication and
# expose deep trade history.

# Maps human-readable timeframes to Coinbase Exchange candle granularities
# (seconds). These are the only granularities the /candles endpoint accepts.
.COINBASE_GRANULARITY_MAP <- list(
  "1min" = 60L,
  "5min" = 300L,
  "15min" = 900L,
  "1hour" = 3600L,
  "6hour" = 21600L,
  "1day" = 86400L
)

#' CoinbaseMarketData: Public Market Data Retrieval
#'
#' Retrieves public market data from the Coinbase Exchange API: products,
#' candles (OHLCV), tick trades, order books, tickers, and server time. None of
#' these endpoints require authentication.
#'
#' Inherits from [CoinbaseBase]. All methods support both synchronous and
#' asynchronous execution depending on the `async` argument at construction.
#'
#' ### Deep history
#' The `/candles` endpoint returns roughly 300 bars per request, so it is a
#' convenience for recent data only. Complete OHLCV at any timeframe is built
#' from ticks: page `get_trades()` (or call the backfill) back through history,
#' then aggregate with [trades_to_ohlcv()].
#'
#' ### Endpoints Covered
#' | Method | Endpoint | Auth |
#' |--------|----------|------|
#' | get_products | GET /products | No |
#' | get_product | GET /products/\{id\} | No |
#' | get_ohlcv | GET /products/\{id\}/candles | No |
#' | get_trades | GET /products/\{id\}/trades | No |
#' | get_orderbook | GET /products/\{id\}/book | No |
#' | get_ticker | GET /products/\{id\}/ticker | No |
#' | get_server_time | GET /time | No |
#'
#' @examples
#' \dontrun{
#' market <- CoinbaseMarketData$new()
#' market$get_ticker("BTC-USD")
#' market$get_ohlcv("BTC-USD", granularity = "1min")
#'
#' # Asynchronous
#' market_async <- CoinbaseMarketData$new(async = TRUE)
#' p <- market_async$get_trades("BTC-USD")
#' }
#'
#' @import data.table
#' @export
CoinbaseMarketData <- R6::R6Class(
  "CoinbaseMarketData",
  inherit = CoinbaseBase,
  public = list(
    #' @description Retrieve all available trading products (currency pairs).
    #' @return A [data.table::data.table] of products, or a promise thereof.
    get_products = function() {
      return(private$.request(
        endpoint = "/products",
        auth = FALSE,
        base_url = private$.exchange_base_url,
        .parser = as_dt_list
      ))
    },

    #' @description Retrieve metadata for a single product.
    #' @param product_id Character; the pair symbol, e.g. `"BTC-USD"`.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    get_product = function(product_id) {
      assert::assert_scalar_character(product_id)
      return(private$.request(
        endpoint = paste0("/products/", product_id),
        auth = FALSE,
        base_url = private$.exchange_base_url,
        .parser = as_dt_row
      ))
    },

    #' @description Retrieve OHLCV candles for a product. Returns roughly 300
    #'   bars per call; for deep history aggregate ticks with [trades_to_ohlcv()].
    #' @param product_id Character; the pair symbol, e.g. `"BTC-USD"`.
    #' @param granularity Character; one of `"1min"`, `"5min"`, `"15min"`,
    #'   `"1hour"`, `"6hour"`, `"1day"`.
    #' @param start POSIXct or NULL; range start. Optional.
    #' @param end POSIXct or NULL; range end. Optional.
    #' @return A [data.table::data.table] with columns `datetime`, `open`,
    #'   `high`, `low`, `close`, `volume`, or a promise thereof.
    get_ohlcv = function(product_id, granularity = "1min", start = NULL, end = NULL) {
      assert::assert_scalar_character(product_id)
      if (!granularity %in% names(.COINBASE_GRANULARITY_MAP)) {
        rlang::abort(paste0(
          "Invalid granularity '", granularity, "'. Valid: ",
          paste(names(.COINBASE_GRANULARITY_MAP), collapse = ", ")
        ))
      }
      query <- list(
        granularity = .COINBASE_GRANULARITY_MAP[[granularity]],
        start = datetime_to_epoch(start),
        end = datetime_to_epoch(end)
      )
      return(private$.request(
        endpoint = paste0("/products/", product_id, "/candles"),
        query = query,
        auth = FALSE,
        base_url = private$.exchange_base_url,
        .parser = parse_candles
      ))
    },

    #' @description Retrieve recent tick trades for a product. To page further
    #'   back, pass the smallest `trade_id` seen as `after`.
    #' @param product_id Character; the pair symbol, e.g. `"BTC-USD"`.
    #' @param limit Integer; trades to return (max 1000). Default 1000.
    #' @param after Numeric or NULL; return trades older than this `trade_id`.
    #' @return A [data.table::data.table] with columns `trade_id`, `side`,
    #'   `price`, `size`, `time`, or a promise thereof.
    get_trades = function(product_id, limit = 1000L, after = NULL) {
      assert::assert_scalar_character(product_id)
      return(private$.request(
        endpoint = paste0("/products/", product_id, "/trades"),
        query = list(limit = as.integer(limit), after = after),
        auth = FALSE,
        base_url = private$.exchange_base_url,
        .parser = parse_trades
      ))
    },

    #' @description Retrieve deep tick history by paging the trades endpoint
    #'   backwards in time. This is the backfill path: pages from the most recent
    #'   trade toward `start` (or the product's first-ever trade if `start` is
    #'   NULL), then deduplicates and sorts ascending. Aggregate the result with
    #'   [trades_to_ohlcv()] for deep OHLCV at any timeframe.
    #' @param product_id Character; the pair symbol, e.g. `"BTC-USD"`.
    #' @param start POSIXct or NULL; stop once trades older than this are reached.
    #' @param end POSIXct or NULL; drop trades newer than this. Paging always
    #'   begins at the most recent trade.
    #' @param max_pages Numeric; cap on pages fetched (each up to 1000 trades).
    #'   Default `Inf`.
    #' @return A [data.table::data.table] with columns `trade_id`, `side`,
    #'   `price`, `size`, `time` sorted ascending by `time`, or a promise thereof.
    get_trades_history = function(product_id, start = NULL, end = NULL, max_pages = Inf) {
      assert::assert_scalar_character(product_id)
      return(coinbase_fetch_trades_history(
        product_id = product_id,
        start = start,
        end = end,
        max_pages = max_pages,
        .req_fn = function(endpoint, query, .parser) {
          private$.request(
            endpoint = endpoint,
            query = query,
            auth = FALSE,
            base_url = private$.exchange_base_url,
            .parser = .parser
          )
        },
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve an order book snapshot for a product.
    #' @param product_id Character; the pair symbol, e.g. `"BTC-USD"`.
    #' @param level Integer; `1` (best bid/ask), `2` (top 50 aggregated), or
    #'   `3` (full, non-aggregated). Default 2.
    #' @return A long [data.table::data.table] with columns `side`, `price`,
    #'   `size`, `num_orders`, or a promise thereof.
    get_orderbook = function(product_id, level = 2L) {
      assert::assert_scalar_character(product_id)
      return(private$.request(
        endpoint = paste0("/products/", product_id, "/book"),
        query = list(level = as.integer(level)),
        auth = FALSE,
        base_url = private$.exchange_base_url,
        .parser = parse_orderbook
      ))
    },

    #' @description Retrieve the latest ticker (best bid/ask, last trade) for a
    #'   product.
    #' @param product_id Character; the pair symbol, e.g. `"BTC-USD"`.
    #' @return A single-row [data.table::data.table], or a promise thereof.
    get_ticker = function(product_id) {
      assert::assert_scalar_character(product_id)
      return(private$.request(
        endpoint = paste0("/products/", product_id, "/ticker"),
        auth = FALSE,
        base_url = private$.exchange_base_url,
        .parser = function(data) {
          dt <- as_dt_row(data)
          if (nrow(dt) == 0L) {
            return(dt)
          }
          num_cols <- intersect(c("ask", "bid", "price", "size", "volume", "rfq_volume"), names(dt))
          dt[, (num_cols) := lapply(.SD, as.numeric), .SDcols = num_cols]
          if ("time" %in% names(dt)) {
            dt[, time := iso_to_datetime(time)]
          }
          return(dt[])
        }
      ))
    },

    #' @description Retrieve the Coinbase Exchange server time.
    #' @return A single-row [data.table::data.table] with `iso` and `epoch`, or
    #'   a promise thereof.
    get_server_time = function() {
      return(private$.request(
        endpoint = "/time",
        auth = FALSE,
        base_url = private$.exchange_base_url,
        .parser = as_dt_row
      ))
    }
  )
)
