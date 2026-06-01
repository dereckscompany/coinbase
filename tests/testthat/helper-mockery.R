# Mock response builders and fixtures for the coinbase README and vignettes.
# Sourced automatically by testthat via the helper prefix convention, and
# imported by mock_router.R so docs render against canned, deterministic data
# with no network, no real credentials, and no funds.
#
# Each mock_cb_*() fixture returns the LIST that becomes the JSON body the
# matching parser consumes. The field names are kept exactly as the parsers in
# R/helpers_parse.R read them (a wrong name yields an NA column), and the shapes
# are grounded in:
#   - the real captured Exchange JSON in /tmp/cb_fixtures/ (public endpoints), and
#   - the Advanced Trade response models in coinbase-advanced-py (auth endpoints).
#
# Coinbase splits across two hosts:
#   - Exchange (public):     https://api.exchange.coinbase.com
#   - Advanced Trade (auth): https://api.coinbase.com

# ---- Core Response Builders ----

#' Build a mock httr2 response with a Coinbase JSON body
#'
#' @param data List to encode as the JSON body.
#' @param status_code Integer; HTTP status code.
#' @return An httr2 response object.
mock_cb_response <- function(data, status_code = 200L) {
  body <- jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")
  return(httr2::response(
    status_code = status_code,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(as.character(body))
  ))
}

#' Build a mock httr2 response with an empty body
#'
#' Several Advanced Trade endpoints (e.g. the intraday-margin SETTER) return a
#' 200 with no body on success. The client parses nothing from it.
#'
#' @param status_code Integer; HTTP status code.
#' @return An httr2 response object with no body.
mock_cb_empty_response <- function(status_code = 200L) {
  return(httr2::response(
    status_code = status_code,
    headers = list(`Content-Type` = "application/json"),
    body = raw(0)
  ))
}

# ---- Public Market Data Fixtures (Exchange host) ----
# Grounded in /tmp/cb_fixtures/*.json. Consumed by CoinbaseMarketData via
# as_dt_list / as_dt_row / parse_candles / parse_trades / parse_orderbook and
# the inline ticker parser.

#' GET /products -> as_dt_list (array of product objects).
mock_cb_products_response <- function() {
  return(list(
    list(
      id = "BTC-USD",
      base_currency = "BTC",
      quote_currency = "USD",
      quote_increment = "0.01",
      base_increment = "0.00000001",
      display_name = "BTC-USD",
      min_market_funds = "1",
      margin_enabled = FALSE,
      post_only = FALSE,
      limit_only = FALSE,
      cancel_only = FALSE,
      status = "online",
      status_message = "",
      trading_disabled = FALSE,
      fx_stablecoin = FALSE,
      max_slippage_percentage = "0.02000000",
      auction_mode = FALSE,
      high_bid_limit_percentage = ""
    ),
    list(
      id = "ETH-USD",
      base_currency = "ETH",
      quote_currency = "USD",
      quote_increment = "0.01",
      base_increment = "0.00000001",
      display_name = "ETH-USD",
      min_market_funds = "1",
      margin_enabled = FALSE,
      post_only = FALSE,
      limit_only = FALSE,
      cancel_only = FALSE,
      status = "online",
      status_message = "",
      trading_disabled = FALSE,
      fx_stablecoin = FALSE,
      max_slippage_percentage = "0.02000000",
      auction_mode = FALSE,
      high_bid_limit_percentage = ""
    ),
    list(
      id = "SOL-USD",
      base_currency = "SOL",
      quote_currency = "USD",
      quote_increment = "0.01",
      base_increment = "0.00000001",
      display_name = "SOL-USD",
      min_market_funds = "1",
      margin_enabled = FALSE,
      post_only = FALSE,
      limit_only = FALSE,
      cancel_only = FALSE,
      status = "online",
      status_message = "",
      trading_disabled = FALSE,
      fx_stablecoin = FALSE,
      max_slippage_percentage = "0.02000000",
      auction_mode = FALSE,
      high_bid_limit_percentage = ""
    )
  ))
}

#' GET /products/{id} -> as_dt_row (single product object).
mock_cb_product_response <- function() {
  return(list(
    id = "BTC-USD",
    base_currency = "BTC",
    quote_currency = "USD",
    quote_increment = "0.01",
    base_increment = "0.00000001",
    display_name = "BTC-USD",
    min_market_funds = "1",
    margin_enabled = FALSE,
    post_only = FALSE,
    limit_only = FALSE,
    cancel_only = FALSE,
    status = "online",
    status_message = "",
    trading_disabled = FALSE,
    fx_stablecoin = FALSE,
    max_slippage_percentage = "0.02000000",
    auction_mode = FALSE,
    high_bid_limit_percentage = ""
  ))
}

#' GET /products/{id}/candles -> parse_candles.
#' Array-of-arrays [time, low, high, open, close, volume], epoch seconds,
#' newest first (the parser sorts ascending).
mock_cb_candles_response <- function() {
  return(list(
    c(1780203360, 74093.59, 74099.83, 74093.60, 74099.83, 0.1151),
    c(1780203300, 74068.26, 74093.61, 74068.26, 74093.60, 0.9691),
    c(1780203240, 74067.15, 74113.49, 74113.49, 74068.26, 3.0535),
    c(1780203180, 74050.00, 74070.12, 74055.40, 74067.15, 1.4820)
  ))
}

#' GET /products/{id}/trades -> parse_trades (array of trade objects).
mock_cb_trades_response <- function() {
  return(list(
    list(
      trade_id = 1026942323,
      side = "sell",
      size = "0.00000052",
      price = "74101.53000000",
      time = "2026-05-31T04:58:29.891511Z"
    ),
    list(
      trade_id = 1026942322,
      side = "sell",
      size = "0.00000240",
      price = "74101.53000000",
      time = "2026-05-31T04:58:29.547159Z"
    ),
    list(
      trade_id = 1026942321,
      side = "buy",
      size = "0.00058315",
      price = "74101.54000000",
      time = "2026-05-31T04:58:29.144132Z"
    ),
    list(
      trade_id = 1026942320,
      side = "buy",
      size = "0.01200000",
      price = "74100.98000000",
      time = "2026-05-31T04:58:28.882001Z"
    )
  ))
}

#' GET /products/{id}/book (level 1-2) -> parse_orderbook.
#' Each level is [price, size, num_orders].
mock_cb_book_response <- function() {
  return(list(
    bids = list(
      c("74101.52", "0.43541938", 5),
      c("74101.38", "0.00067474", 1),
      c("74098.69", "0.00266800", 1)
    ),
    asks = list(
      c("74101.53", "0.08631688", 7),
      c("74103.63", "0.26058806", 2),
      c("74103.66", "0.00140588", 2)
    ),
    sequence = 129229908439,
    auction_mode = FALSE,
    auction = list(),
    time = "2026-05-31T04:58:29.012929965Z"
  ))
}

#' GET /products/{id}/book?level=3 -> parse_orderbook (level 3).
#' The third element of each level is an order_id STRING (non-aggregated book).
mock_cb_book_l3_response <- function() {
  return(list(
    bids = list(
      list("74101.52", "0.21000000", "b1a2c3d4-0001-4aaa-8bbb-000000000001"),
      list("74101.52", "0.22541938", "b1a2c3d4-0002-4aaa-8bbb-000000000002"),
      list("74098.69", "0.00266800", "b1a2c3d4-0003-4aaa-8bbb-000000000003")
    ),
    asks = list(
      list("74101.53", "0.04000000", "a1a2c3d4-0001-4aaa-8bbb-000000000001"),
      list("74101.53", "0.04631688", "a1a2c3d4-0002-4aaa-8bbb-000000000002"),
      list("74103.66", "0.00140588", "a1a2c3d4-0003-4aaa-8bbb-000000000003")
    ),
    sequence = 129229908440,
    auction_mode = FALSE,
    auction = list(),
    time = "2026-05-31T04:58:29.512929965Z"
  ))
}

#' GET /products/{id}/ticker -> inline ticker parser (as_dt_row + numeric coerce).
mock_cb_ticker_response <- function() {
  return(list(
    ask = "74101.53",
    bid = "74101.52",
    volume = "3600.23109176",
    trade_id = 1026942323,
    price = "74101.53",
    size = "0.00000052",
    time = "2026-05-31T04:58:29.891511032Z",
    rfq_volume = "10.792896"
  ))
}

#' GET /time -> as_dt_row (server time).
mock_cb_time_response <- function() {
  return(list(
    iso = "2026-05-31T04:58:31.547Z",
    epoch = 1780203511.547
  ))
}

#' GET /products/stats -> parse_stats (bulk: object keyed by product id, each
#' with stats_24hour + stats_30day sub-objects).
mock_cb_stats_response <- function() {
  return(list(
    `BTC-USD` = list(
      stats_24hour = list(
        open = "73504.38",
        high = "74156.59",
        low = "73382",
        last = "73958",
        volume = "3477.63",
        rfq_volume = "10.52"
      ),
      stats_30day = list(volume = "177000.51", rfq_volume = "1393.91")
    ),
    `ETH-USD` = list(
      stats_24hour = list(
        open = "2400.10",
        high = "2455.00",
        low = "2390.00",
        last = "2440.55",
        volume = "55000.00",
        rfq_volume = "120.00"
      ),
      stats_30day = list(volume = "1500000.00", rfq_volume = "9000.00")
    ),
    `SOL-USD` = list(
      stats_24hour = list(
        open = "150.00",
        high = "162.00",
        low = "148.00",
        last = "159.80",
        volume = "900000.00",
        rfq_volume = "500.00"
      ),
      stats_30day = list(volume = "28000000.00", rfq_volume = "40000.00")
    )
  ))
}

#' GET /products/{id}/stats -> parse_product_stats (single product 24h+30day).
mock_cb_product_stats_response <- function() {
  return(list(
    open = "73504.38",
    high = "74156.59",
    low = "73382",
    last = "73958",
    volume = "3477.63040388",
    volume_30day = "177000.51576397",
    rfq_volume_24hour = "10.526361",
    rfq_volume_30day = "1393.919788",
    conversions_volume_24hour = "0.000000",
    conversions_volume_30day = "0.000000"
  ))
}

#' GET /api/v3/brokerage/best_bid_ask -> parse_best_bid_ask (pricebooks array).
mock_cb_best_bid_ask_response <- function() {
  return(list(
    pricebooks = list(
      list(
        product_id = "BTC-USD",
        bids = list(list(price = "74101.52", size = "0.43541938")),
        asks = list(list(price = "74101.53", size = "0.08631688")),
        time = "2026-05-31T04:58:29.012929Z"
      ),
      list(
        product_id = "ETH-USD",
        bids = list(list(price = "2440.50", size = "12.0")),
        asks = list(list(price = "2440.60", size = "8.5")),
        time = "2026-05-31T04:58:29.012929Z"
      )
    )
  ))
}

# ---- Account Fixtures (Advanced Trade host) ----
# Consumed by CoinbaseAccount.

#' GET /accounts -> parse_accounts via the cursor paginator.
#' has_next FALSE + empty cursor stop the walk after one page.
mock_cb_accounts_response <- function() {
  return(list(
    accounts = list(
      list(
        uuid = "8bfc20d7-f7c6-4422-bf07-8243ca4169fe",
        name = "BTC Wallet",
        currency = "BTC",
        available_balance = list(value = "0.53210000", currency = "BTC"),
        default = TRUE,
        active = TRUE,
        created_at = "2024-01-10T10:00:00Z",
        updated_at = "2026-05-30T18:40:29.980Z",
        type = "ACCOUNT_TYPE_CRYPTO",
        ready = TRUE,
        hold = list(value = "0.00000000", currency = "BTC"),
        retail_portfolio_id = "9c2f8b1e-1111-4d3a-9aaa-0123456789ab",
        platform = "ACCOUNT_PLATFORM_CONSUMER"
      ),
      list(
        uuid = "1a2b3c4d-5e6f-4789-90ab-cdef01234567",
        name = "USD Wallet",
        currency = "USD",
        available_balance = list(value = "12500.42", currency = "USD"),
        default = TRUE,
        active = TRUE,
        created_at = "2024-01-10T10:00:00Z",
        updated_at = "2026-05-30T18:40:29.980Z",
        type = "ACCOUNT_TYPE_FIAT",
        ready = TRUE,
        hold = list(value = "250.00", currency = "USD"),
        retail_portfolio_id = "9c2f8b1e-1111-4d3a-9aaa-0123456789ab",
        platform = "ACCOUNT_PLATFORM_CONSUMER"
      )
    ),
    has_next = FALSE,
    cursor = "",
    size = 2L
  ))
}

#' GET /accounts/{uuid} -> parse_accounts(list(body$account)).
mock_cb_account_response <- function() {
  return(list(
    account = list(
      uuid = "8bfc20d7-f7c6-4422-bf07-8243ca4169fe",
      name = "BTC Wallet",
      currency = "BTC",
      available_balance = list(value = "0.53210000", currency = "BTC"),
      default = TRUE,
      active = TRUE,
      created_at = "2024-01-10T10:00:00Z",
      updated_at = "2026-05-30T18:40:29.980Z",
      type = "ACCOUNT_TYPE_CRYPTO",
      ready = TRUE,
      hold = list(value = "0.00000000", currency = "BTC"),
      retail_portfolio_id = "9c2f8b1e-1111-4d3a-9aaa-0123456789ab",
      platform = "ACCOUNT_PLATFORM_CONSUMER"
    )
  ))
}

#' GET /transaction_summary -> parse_fees (flattens nested fee_tier).
mock_cb_fees_response <- function() {
  return(list(
    total_volume = 125000.50,
    total_fees = 312.75,
    total_balance = "13050.42",
    fee_tier = list(
      pricing_tier = "Advanced 1",
      usd_from = "0",
      usd_to = "1000",
      taker_fee_rate = "0.0060",
      maker_fee_rate = "0.0040",
      aop_from = "0",
      aop_to = "0"
    ),
    advanced_trade_only_volumes = 125000.50,
    advanced_trade_only_fees = 312.75,
    has_promo_fee = FALSE
  ))
}

#' GET /portfolios -> as_dt_list(body$portfolios).
mock_cb_portfolios_response <- function() {
  return(list(
    portfolios = list(
      list(name = "Default", uuid = "9c2f8b1e-1111-4d3a-9aaa-0123456789ab", type = "DEFAULT"),
      list(name = "Algo", uuid = "7d6e5f4c-2222-4b1a-8ccc-fedcba987654", type = "CONSUMER")
    )
  ))
}

#' GET /portfolios/{uuid} -> parse_portfolio_breakdown (positions) and
#' parse_portfolio_summary (totals); both read this same endpoint.
mock_cb_portfolio_breakdown_response <- function() {
  return(list(
    breakdown = list(
      portfolio = list(name = "Algo", uuid = "7d6e5f4c-2222-4b1a-8ccc-fedcba987654", type = "CONSUMER"),
      portfolio_balances = list(
        total_balance = list(value = "125000.00", currency = "USD"),
        total_futures_balance = list(value = "25000.00", currency = "USD"),
        total_cash_equivalent_balance = list(value = "40000.00", currency = "USD"),
        total_crypto_balance = list(value = "85000.00", currency = "USD"),
        futures_unrealized_pnl = list(value = "120.00", currency = "USD"),
        perp_unrealized_pnl = list(value = "45.00", currency = "USD"),
        total_equities_balance = list(value = "0.00", currency = "USD")
      ),
      spot_positions = list(
        list(
          asset = "BTC",
          account_uuid = "a1-spot",
          total_balance_crypto = 0.81,
          total_balance_fiat = 60000.0,
          available_to_trade_crypto = 0.80,
          allocation = 0.48,
          unrealized_pnl = 5000.0,
          average_entry_price = list(value = "67900.00", currency = "USD"),
          cost_basis = list(value = "55000.00", currency = "USD"),
          is_cash = FALSE
        ),
        list(
          asset = "USD",
          account_uuid = "a2-spot",
          total_balance_crypto = 40000.0,
          total_balance_fiat = 40000.0,
          available_to_trade_crypto = 40000.0,
          allocation = 0.32,
          unrealized_pnl = 0.0,
          cost_basis = list(value = "40000.00", currency = "USD"),
          is_cash = TRUE
        )
      ),
      futures_positions = list(
        list(
          product_id = "BIT-28FEB26-CDE",
          side = "LONG",
          amount = 2.0,
          contract_size = 0.01,
          avg_entry_price = "95000.00",
          current_price = "96000.00",
          unrealized_pnl = "120.00",
          notional_value = "1920.00",
          expiry = "2026-02-28T00:00:00Z",
          underlying_asset = "BTC",
          venue = "FCM"
        )
      ),
      perp_positions = list(
        list(
          product_id = "BTC-PERP-INTX",
          symbol = "BTC-PERP",
          position_side = "LONG",
          net_size = "1.5",
          vwap = list(
            userNativeCurrency = list(value = "94000.00", currency = "USD"),
            rawCurrency = list(value = "94000.00", currency = "USDC")
          ),
          mark_price = list(
            userNativeCurrency = list(value = "95500.00", currency = "USD"),
            rawCurrency = list(value = "95500.00", currency = "USDC")
          ),
          unrealized_pnl = list(
            userNativeCurrency = list(value = "45.00", currency = "USD"),
            rawCurrency = list(value = "45.00", currency = "USDC")
          ),
          liquidation_price = list(
            userNativeCurrency = list(value = "80000.00", currency = "USD"),
            rawCurrency = list(value = "80000.00", currency = "USDC")
          ),
          leverage = "5",
          margin_type = "CROSS"
        )
      )
    )
  ))
}

#' GET /key_permissions -> as_dt_row.
mock_cb_key_permissions_response <- function() {
  return(list(
    can_view = TRUE,
    can_trade = TRUE,
    can_transfer = FALSE,
    portfolio_uuid = "9c2f8b1e-1111-4d3a-9aaa-0123456789ab",
    portfolio_type = "DEFAULT"
  ))
}

# ---- Trading Fixtures (Advanced Trade host) ----
# Consumed by CoinbaseTrading.

#' GET /orders/historical/batch -> parse_orders via the cursor paginator.
#' has_next FALSE + empty cursor stop the walk after one page. Each order
#' carries a nested order_configuration that parse_orders flattens.
mock_cb_orders_response <- function() {
  return(list(
    orders = list(
      list(
        order_id = "1111aaaa-2222-bbbb-3333-cccccccccccc",
        product_id = "BTC-USD",
        side = "BUY",
        client_order_id = "client-001",
        status = "OPEN",
        time_in_force = "GOOD_UNTIL_CANCELLED",
        created_time = "2026-05-30T18:30:00Z",
        completion_percentage = "0",
        filled_size = "0",
        average_filled_price = "0",
        number_of_fills = "0",
        filled_value = "0",
        total_fees = "0",
        order_type = "LIMIT",
        order_configuration = list(
          limit_limit_gtc = list(
            base_size = "0.001",
            limit_price = "70000.00",
            post_only = FALSE
          )
        )
      ),
      list(
        order_id = "4444dddd-5555-eeee-6666-ffffffffffff",
        product_id = "ETH-USD",
        side = "SELL",
        client_order_id = "client-002",
        status = "FILLED",
        time_in_force = "IMMEDIATE_OR_CANCEL",
        created_time = "2026-05-30T18:31:00Z",
        completion_percentage = "100",
        filled_size = "0.5",
        average_filled_price = "3850.20",
        number_of_fills = "2",
        filled_value = "1925.10",
        total_fees = "7.70",
        order_type = "MARKET",
        order_configuration = list(
          market_market_ioc = list(
            base_size = "0.5"
          )
        )
      )
    ),
    cursor = "",
    has_next = FALSE
  ))
}

#' GET /orders/historical/{id} -> parse_orders(list(body$order)).
mock_cb_order_response <- function() {
  return(list(
    order = list(
      order_id = "1111aaaa-2222-bbbb-3333-cccccccccccc",
      product_id = "BTC-USD",
      side = "BUY",
      client_order_id = "client-001",
      status = "OPEN",
      time_in_force = "GOOD_UNTIL_CANCELLED",
      created_time = "2026-05-30T18:30:00Z",
      completion_percentage = "0",
      filled_size = "0",
      average_filled_price = "0",
      number_of_fills = "0",
      filled_value = "0",
      total_fees = "0",
      order_type = "LIMIT",
      order_configuration = list(
        limit_limit_gtc = list(
          base_size = "0.001",
          limit_price = "70000.00",
          post_only = FALSE
        )
      )
    )
  ))
}

#' GET /orders/historical/fills -> parse_fills via the cursor paginator.
#' The fills endpoint omits has_next; an empty cursor stops the walk.
mock_cb_fills_response <- function() {
  return(list(
    fills = list(
      list(
        entry_id = "entry-0001",
        trade_id = "trade-0001",
        order_id = "4444dddd-5555-eeee-6666-ffffffffffff",
        product_id = "ETH-USD",
        side = "SELL",
        trade_time = "2026-05-30T18:31:02Z",
        trade_type = "FILL",
        price = "3850.20",
        size = "0.3",
        commission = "4.62",
        size_in_quote = FALSE,
        liquidity_indicator = "TAKER"
      ),
      list(
        entry_id = "entry-0002",
        trade_id = "trade-0002",
        order_id = "4444dddd-5555-eeee-6666-ffffffffffff",
        product_id = "ETH-USD",
        side = "SELL",
        trade_time = "2026-05-30T18:31:03Z",
        trade_type = "FILL",
        price = "3850.20",
        size = "0.2",
        commission = "3.08",
        size_in_quote = FALSE,
        liquidity_indicator = "TAKER"
      )
    ),
    cursor = ""
  ))
}

#' POST /orders/preview -> parse_preview. Empty errs array -> NA errs column.
mock_cb_preview_response <- function() {
  return(list(
    order_total = "10.06",
    commission_total = "0.06",
    errs = list(),
    warning = list(),
    quote_size = "10.00",
    base_size = "0.000135",
    best_bid = "74101.52",
    best_ask = "74101.53",
    is_max = FALSE,
    slippage = "0.0001",
    preview_id = "prev-1234-5678-90ab"
  ))
}

#' POST /orders -> parse_create_order (success path).
mock_cb_create_order_response <- function() {
  return(list(
    success = TRUE,
    success_response = list(
      order_id = "1111aaaa-2222-bbbb-3333-cccccccccccc",
      product_id = "BTC-USD",
      side = "BUY",
      client_order_id = "client-001"
    ),
    order_configuration = list(
      market_market_ioc = list(
        quote_size = "10.00"
      )
    )
  ))
}

#' POST /orders/close_position -> parse_create_order (close-position response).
mock_cb_close_position_response <- function() {
  return(list(
    success = TRUE,
    success_response = list(
      order_id = "4444dddd-5555-eeee-6666-ffffffffffff",
      product_id = "BIT-28FEB25-CDE",
      side = "BUY",
      client_order_id = "client-close-001"
    ),
    order_configuration = list(
      market_market_ioc = list(
        base_size = "1"
      )
    )
  ))
}

#' POST /orders/edit -> parse_edit_order (success, empty errors array).
mock_cb_edit_order_response <- function() {
  return(list(
    success = TRUE,
    success_response = list(
      order_id = "1111aaaa-2222-bbbb-3333-cccccccccccc"
    ),
    errors = list()
  ))
}

#' POST /orders/edit_preview -> parse_edit_preview (empty errors array).
mock_cb_edit_preview_response <- function() {
  return(list(
    errors = list(),
    slippage = "0.0002",
    order_total = "70.07",
    commission_total = "0.07",
    quote_size = "70.00",
    base_size = "0.001",
    best_bid = "74101.52",
    average_filled_price = "0"
  ))
}

#' POST /orders/batch_cancel -> parse_cancel_results(body$results).
mock_cb_cancel_orders_response <- function() {
  return(list(
    results = list(
      list(
        order_id = "1111aaaa-2222-bbbb-3333-cccccccccccc",
        success = TRUE,
        failure_reason = "UNKNOWN_CANCEL_FAILURE_REASON"
      )
    )
  ))
}

# ---- Futures (CFM) Fixtures (Advanced Trade host) ----
# Consumed by CoinbaseFutures. BTC ~74000 context throughout.

#' GET /cfm/balance_summary -> parse_futures_balance(body$balance_summary).
#' All monetary fields are nested {value, currency}; flex_num extracts value.
mock_cb_futures_balance_response <- function() {
  return(list(
    balance_summary = list(
      futures_buying_power = list(value = "9500.00", currency = "USD"),
      total_usd_balance = list(value = "10000.00", currency = "USD"),
      cbi_usd_balance = list(value = "2000.00", currency = "USD"),
      cfm_usd_balance = list(value = "8000.00", currency = "USD"),
      total_open_orders_hold_amount = list(value = "0.00", currency = "USD"),
      unrealized_pnl = list(value = "-125.40", currency = "USD"),
      daily_realized_pnl = list(value = "42.10", currency = "USD"),
      initial_margin = list(value = "740.00", currency = "USD"),
      available_margin = list(value = "7260.00", currency = "USD"),
      liquidation_threshold = list(value = "370.00", currency = "USD"),
      liquidation_buffer_amount = list(value = "7630.00", currency = "USD"),
      liquidation_buffer_percentage = "95.4"
    )
  ))
}

#' GET /cfm/positions -> parse_futures_positions(body$positions).
#' A single short position. expiration_time is parsed as an ISO datetime.
mock_cb_futures_positions_response <- function() {
  return(list(
    positions = list(
      list(
        product_id = "BIT-31OCT26-CDE",
        expiration_time = "2026-10-31T16:00:00Z",
        side = "SHORT",
        number_of_contracts = "3",
        current_price = "74101.53",
        avg_entry_price = "74500.00",
        unrealized_pnl = "-125.40",
        daily_realized_pnl = "42.10"
      )
    )
  ))
}

#' GET /cfm/positions/{id} -> parse_futures_positions(list(body$position)).
mock_cb_futures_position_response <- function() {
  return(list(
    position = list(
      product_id = "BIT-31OCT26-CDE",
      expiration_time = "2026-10-31T16:00:00Z",
      side = "SHORT",
      number_of_contracts = "3",
      current_price = "74101.53",
      avg_entry_price = "74500.00",
      unrealized_pnl = "-125.40",
      daily_realized_pnl = "42.10"
    )
  ))
}

#' GET /cfm/sweeps -> parse_futures_sweeps(body$sweeps).
#' requested_amount is nested {value, currency}; schedule_time is an ISO string.
mock_cb_futures_sweeps_response <- function() {
  return(list(
    sweeps = list(
      list(
        id = "sweep-0001",
        requested_amount = list(value = "500.00", currency = "USD"),
        should_sweep_all = FALSE,
        status = "PENDING",
        schedule_time = "2026-05-31T00:00:00Z"
      )
    )
  ))
}

#' POST /cfm/sweeps/schedule -> as_dt_row (success flag).
mock_cb_schedule_sweep_response <- function() {
  return(list(success = TRUE))
}

#' DELETE /cfm/sweeps -> as_dt_row (success flag).
mock_cb_cancel_sweep_response <- function() {
  return(list(success = TRUE))
}

#' GET /cfm/intraday/margin_setting -> as_dt_row (flat object).
mock_cb_intraday_margin_setting_response <- function() {
  return(list(setting = "INTRADAY_MARGIN_SETTING_STANDARD"))
}

#' GET /cfm/intraday/current_margin_window -> parse_margin_window.
#' Flattens the nested margin_window object plus the top-level killswitch flags.
mock_cb_current_margin_window_response <- function() {
  return(list(
    margin_window = list(
      margin_window_type = "FCM_MARGIN_WINDOW_TYPE_OVERNIGHT",
      end_time = "2026-05-31T13:30:00Z"
    ),
    is_intraday_margin_killswitch_enabled = FALSE,
    is_intraday_margin_enrollment_killswitch_enabled = FALSE
  ))
}

# Note: POST /cfm/intraday/margin_setting (the SETTER) returns an EMPTY body on
# success. It has no fixture function — the router answers it with
# mock_cb_empty_response() directly.
