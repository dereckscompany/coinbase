# File: R/types_coinbase.R
# Reusable roxyassert `@type` shapes for the `data.table`s the public R6 methods
# return. Each table-returning method documents its return as one of these named
# shapes via `(Shape | promise<Shape>)`; the contract roclet expands the shape
# into that method's generated `assert_return_*` helper, so every column's
# presence and type is enforced at the public boundary — for both the synchronous
# value and the resolved value of a promise (wired through
# `connectcore::then_or_now()`). The internal parsers in R/helpers_parse.R build
# the same shapes, and their empty branches return the fully-typed zero-row table
# (`empty_*()`) so the method's column contract still holds on an empty result.

#' @title Coinbase return shapes
#' @description Reusable roxyassert `@type` shapes for the parsed Coinbase
#' `data.table`s. Every column is typed to what the parser actually produces:
#' `numeric` is the strict double (the package convention); a column is marked
#' `| NA` wherever the parser can emit a missing value -- which is most of them,
#' because the parsers coalesce absent JSON fields to `NA` (`num_or_na`,
#' `coalesce_null(.., NA_character_)`, `iso_to_datetime` on a missing string) and
#' the field may legitimately be absent in a real response. So that an empty
#' result still satisfies its contract, each parser's empty branch returns the
#' fully-typed zero-row table for its shape (see `empty_*()` in
#' R/helpers_parse.R) rather than a bare schemaless `data.table()`.
#'
#' Shapes: `Products`, `Ohlcv`, `Trades`, `Stats`, `ProductStats`, `BestBidAsk`,
#' `Accounts`, `Fees`, `OrderConfig` (the flattened `order_configuration`
#' record), `Orders`, `Fills`, `Preview`, `CreateOrderAck`, `EditOrderAck`,
#' `EditPreview`, `CancelResults`, `MarginWindow`, `FuturesBalance`,
#' `FuturesPositions`, `FuturesSweeps`, `PortfolioSummary`. The order book
#' (`parse_orderbook`) and the portfolio breakdown (`parse_portfolio_breakdown`)
#' return level/source-dependent column sets and are documented inline at those
#' parsers.
#'
#' `@genassert` emits a standalone `assert_type_<Shape>()` for each shape (so the
#' `OrderConfig` record built inside `parse_orders()` / `parse_create_order()`
#' can be validated even though it is never a public argument), and
#' `@exportassert` exports them so a downstream package can validate against
#' coinbase's shapes.
#' @name coinbase_shapes
#' @genassert
#' @exportassert
#'
#' @type Products (data.table) one row per tradable product (Exchange `/products`):
#' - id (character | NA) the product id, e.g. `"BTC-USD"`.
#' - base_currency (character | NA) the base asset.
#' - quote_currency (character | NA) the quote asset.
#' - quote_increment (character | NA) quote price increment (verbatim string).
#' - base_increment (character | NA) base size increment (verbatim string).
#' - display_name (character | NA) human-readable name.
#' - min_market_funds (character | NA) minimum order value in the quote asset.
#' - margin_enabled (logical | NA) whether margin trading is enabled.
#' - post_only (logical | NA) whether the book is post-only.
#' - limit_only (logical | NA) whether the book is limit-only.
#' - cancel_only (logical | NA) whether the book is cancel-only.
#' - status (character | NA) listing status, e.g. `"online"`.
#' - status_message (character | NA) free-text status note (`""` when none).
#' - trading_disabled (logical | NA) whether trading is disabled.
#' - fx_stablecoin (logical | NA) whether the pair is an FX stablecoin pair.
#' - max_slippage_percentage (character | NA) max slippage (verbatim string).
#' - auction_mode (logical | NA) whether the book is in auction mode.
#' - high_bid_limit_percentage (character | NA) high-bid limit (`""` when none).
#'
#' @type Ohlcv (data.table) one row per candle, ascending by `datetime`:
#' - datetime (POSIXct | NA) candle open time (UTC).
#' - open (numeric | NA) open price.
#' - high (numeric | NA) high price.
#' - low (numeric | NA) low price.
#' - close (numeric | NA) close price.
#' - volume (numeric | NA) traded volume.
#'
#' @type Trades (data.table) one row per tick trade:
#' - trade_id (numeric | NA) exchange trade id.
#' - side (character | NA) aggressor side (`"buy"`/`"sell"`).
#' - price (numeric | NA) trade price.
#' - size (numeric | NA) trade size in the base asset.
#' - time (POSIXct | NA) trade time (UTC).
#'
#' @type Stats (data.table) one row per product, the bulk 24h/30d stats scan:
#' - product_id (character | NA) the product id.
#' - open (numeric | NA) 24h open price.
#' - high (numeric | NA) 24h high price.
#' - low (numeric | NA) 24h low price.
#' - last (numeric | NA) last traded price.
#' - volume (numeric | NA) 24h volume.
#' - volume_30day (numeric | NA) 30-day volume.
#'
#' @type ProductStats (data.table) one row, a single product's 24h/30d stats:
#' - open (numeric | NA) 24h open price.
#' - high (numeric | NA) 24h high price.
#' - low (numeric | NA) 24h low price.
#' - last (numeric | NA) last traded price.
#' - volume (numeric | NA) 24h volume.
#' - volume_30day (numeric | NA) 30-day volume.
#' - rfq_volume_24hour (numeric | NA) 24h RFQ volume.
#' - rfq_volume_30day (numeric | NA) 30-day RFQ volume.
#' - conversions_volume_24hour (numeric | NA) 24h conversions volume.
#' - conversions_volume_30day (numeric | NA) 30-day conversions volume.
#'
#' @type BestBidAsk (data.table) one row per product, best bid/ask snapshot:
#' - product_id (character | NA) the product id.
#' - bid_price (numeric | NA) best bid price.
#' - bid_size (numeric | NA) best bid size.
#' - ask_price (numeric | NA) best ask price.
#' - ask_size (numeric | NA) best ask size.
#' - time (POSIXct | NA) snapshot time (UTC).
#'
#' @type Accounts (data.table) one row per trading account:
#' - uuid (character | NA) account UUID.
#' - name (character | NA) account name.
#' - currency (character | NA) the account's asset code.
#' - available_balance (numeric | NA) amount available to trade.
#' - hold (numeric | NA) amount held in open orders.
#' - active (logical | NA) whether the account is active.
#' - default (logical | NA) whether it is the default account for its currency.
#' - ready (logical | NA) whether the account is ready.
#' - type (character | NA) account type, e.g. `"ACCOUNT_TYPE_CRYPTO"`.
#' - platform (character | NA) platform, e.g. `"ACCOUNT_PLATFORM_CONSUMER"`.
#' - retail_portfolio_id (character | NA) owning portfolio UUID.
#' - created_at (POSIXct | NA) creation time (UTC).
#' - updated_at (POSIXct | NA) last update time (UTC).
#'
#' @type Fees (data.table) one row, the transaction/fee summary with the current
#'   maker/taker tier:
#' - pricing_tier (character | NA) the fee-tier name, e.g. `"Advanced 1"`.
#' - maker_fee_rate (numeric | NA) maker fee rate.
#' - taker_fee_rate (numeric | NA) taker fee rate.
#' - usd_from (numeric | NA) lower USD-volume bound of the tier.
#' - usd_to (numeric | NA) upper USD-volume bound of the tier.
#' - total_volume (numeric | NA) trailing total volume.
#' - total_fees (numeric | NA) trailing total fees.
#' - total_balance (numeric | NA) total account balance.
#'
#' @type OrderConfig (list) the flattened `order_configuration` record produced by
#'   `flatten_order_config()` and spliced into `Orders` / `CreateOrderAck`:
#' - config_type (scalar<character | NA>) the inner order-type key, e.g.
#'   `"limit_limit_gtc"`.
#' - base_size (scalar<numeric | NA>) base size.
#' - quote_size (scalar<numeric | NA>) quote (notional) size.
#' - limit_price (scalar<numeric | NA>) limit price.
#' - stop_price (scalar<numeric | NA>) stop price.
#' - stop_trigger_price (scalar<numeric | NA>) bracket trigger price.
#' - stop_direction (scalar<character | NA>) stop direction.
#' - end_time (scalar<POSIXct | NA>) good-till time (UTC).
#' - post_only (scalar<logical | NA>) post-only flag.
#'
#' @type Orders (data.table) one row per order, scalar fields plus the flattened
#'   `order_configuration`:
#' - order_id (character | NA) exchange order id.
#' - client_order_id (character | NA) client-assigned id.
#' - product_id (character | NA) the product id.
#' - side (character | NA) order side (`"BUY"`/`"SELL"`).
#' - status (character | NA) order status, e.g. `"OPEN"`, `"FILLED"`.
#' - order_type (character | NA) coarse API order type, e.g. `"LIMIT"`.
#' - config_type (character | NA) detailed order-type key from `order_configuration`.
#' - time_in_force (character | NA) time-in-force policy.
#' - created_time (POSIXct | NA) creation time (UTC).
#' - completion_percentage (numeric | NA) percent filled.
#' - filled_size (numeric | NA) base amount filled.
#' - average_filled_price (numeric | NA) VWAP of fills.
#' - number_of_fills (numeric | NA) count of fills.
#' - filled_value (numeric | NA) quote value filled.
#' - total_fees (numeric | NA) total fees.
#' - base_size (numeric | NA) configured base size.
#' - quote_size (numeric | NA) configured quote size.
#' - limit_price (numeric | NA) configured limit price.
#' - stop_price (numeric | NA) configured stop price.
#' - stop_trigger_price (numeric | NA) configured bracket trigger price.
#' - stop_direction (character | NA) configured stop direction.
#' - end_time (POSIXct | NA) configured good-till time (UTC).
#' - post_only (logical | NA) configured post-only flag.
#'
#' @type Fills (data.table) one row per fill:
#' - entry_id (character | NA) ledger entry id.
#' - trade_id (character | NA) trade id.
#' - order_id (character | NA) the order this fill belongs to.
#' - product_id (character | NA) the product id.
#' - side (character | NA) order side (`"BUY"`/`"SELL"`).
#' - trade_time (POSIXct | NA) fill time (UTC).
#' - trade_type (character | NA) trade type, e.g. `"FILL"`.
#' - price (numeric | NA) fill price.
#' - size (numeric | NA) fill size in the base asset.
#' - commission (numeric | NA) fee charged for this fill.
#' - size_in_quote (logical | NA) whether `size` is expressed in the quote asset.
#' - liquidity_indicator (character | NA) maker/taker indicator.
#'
#' @type Preview (data.table) one row, an order-preview (dry-run) estimate:
#' - order_total (numeric | NA) estimated order total.
#' - commission_total (numeric | NA) estimated commission.
#' - quote_size (numeric | NA) estimated quote size.
#' - base_size (numeric | NA) estimated base size.
#' - best_bid (numeric | NA) best bid at preview time.
#' - best_ask (numeric | NA) best ask at preview time.
#' - slippage (numeric | NA) estimated slippage.
#' - errs (character | NA) collapsed validation errors, `NA` if none.
#' - preview_id (character | NA) the preview id.
#'
#' @type CreateOrderAck (data.table) one row, a create-order acknowledgement with
#'   the flattened `order_configuration`:
#' - success (logical | NA) whether the order was accepted.
#' - order_id (character | NA) the new order id.
#' - product_id (character | NA) the product id.
#' - side (character | NA) order side (`"BUY"`/`"SELL"`).
#' - client_order_id (character | NA) client-assigned id.
#' - failure_reason (character | NA) collapsed failure reason, `NA` on success.
#' - config_type (character | NA) detailed order-type key.
#' - base_size (numeric | NA) configured base size.
#' - quote_size (numeric | NA) configured quote size.
#' - limit_price (numeric | NA) configured limit price.
#' - stop_price (numeric | NA) configured stop price.
#' - stop_trigger_price (numeric | NA) configured bracket trigger price.
#'
#' @type EditOrderAck (data.table) one row, an edit-order acknowledgement:
#' - success (logical | NA) whether the edit was accepted.
#' - order_id (character | NA) the edited order id.
#' - errors (character | NA) collapsed errors, `NA` if none.
#'
#' @type EditPreview (data.table) one row, an edit-order preview (dry-run):
#' - errors (character | NA) collapsed errors, `NA` if none.
#' - slippage (numeric | NA) estimated slippage.
#' - order_total (numeric | NA) estimated order total.
#' - commission_total (numeric | NA) estimated commission.
#' - quote_size (numeric | NA) estimated quote size.
#' - base_size (numeric | NA) estimated base size.
#' - best_bid (numeric | NA) best bid at preview time.
#' - average_filled_price (numeric | NA) average filled price estimate.
#'
#' @type CancelResults (data.table) one row per cancel request:
#' - order_id (character | NA) the order id targeted.
#' - success (logical | NA) whether the cancel was accepted.
#' - failure_reason (character | NA) collapsed failure reason, `NA` on success.
#'
#' @type MarginWindow (data.table) one row, the current CFM intraday-margin window:
#' - margin_window_type (character | NA) the window type.
#' - end_time (POSIXct | NA) when the window ends (UTC).
#' - is_intraday_margin_killswitch_enabled (logical | NA) killswitch flag.
#' - is_intraday_margin_enrollment_killswitch_enabled (logical | NA) enrollment
#'   killswitch flag.
#'
#' @type FuturesBalance (data.table) one row, the CFM futures balance summary:
#' - futures_buying_power (numeric | NA) futures buying power.
#' - total_usd_balance (numeric | NA) total USD balance.
#' - cbi_usd_balance (numeric | NA) spot (CBI) USD balance.
#' - cfm_usd_balance (numeric | NA) futures (CFM) USD balance.
#' - total_open_orders_hold_amount (numeric | NA) hold across open orders.
#' - unrealized_pnl (numeric | NA) unrealised PnL.
#' - daily_realized_pnl (numeric | NA) realised PnL for the day.
#' - initial_margin (numeric | NA) initial margin requirement.
#' - available_margin (numeric | NA) margin available.
#' - liquidation_threshold (numeric | NA) liquidation threshold.
#' - liquidation_buffer_amount (numeric | NA) liquidation buffer amount.
#' - liquidation_buffer_percentage (numeric | NA) liquidation buffer percent.
#'
#' @type FuturesPositions (data.table) one row per open CFM futures position:
#' - product_id (character | NA) the futures product id.
#' - side (character | NA) position side (`"LONG"`/`"SHORT"`).
#' - number_of_contracts (numeric | NA) contracts held.
#' - current_price (numeric | NA) current mark price.
#' - avg_entry_price (numeric | NA) average entry price.
#' - unrealized_pnl (numeric | NA) unrealised PnL.
#' - daily_realized_pnl (numeric | NA) realised PnL for the day.
#' - expiration_time (POSIXct | NA) contract expiry (UTC).
#'
#' @type FuturesSweeps (data.table) one row per scheduled/pending cash sweep:
#' - id (character | NA) the sweep id.
#' - requested_amount (numeric | NA) requested USD amount.
#' - should_sweep_all (logical | NA) whether the full balance is swept.
#' - status (character | NA) sweep status, e.g. `"PENDING"`.
#' - schedule_time (POSIXct | NA) when the sweep is scheduled (UTC).
#'
#' @type PortfolioSummary (data.table) one row, a portfolio's aggregate totals:
#' - uuid (character | NA) the portfolio UUID.
#' - name (character | NA) the portfolio name.
#' - type (character | NA) the portfolio type.
#' - total_balance (numeric | NA) total portfolio balance.
#' - total_futures_balance (numeric | NA) total futures balance.
#' - total_cash_equivalent_balance (numeric | NA) total cash-equivalent balance.
#' - total_crypto_balance (numeric | NA) total crypto balance.
#' - futures_unrealized_pnl (numeric | NA) futures unrealised PnL.
#' - perp_unrealized_pnl (numeric | NA) perpetuals unrealised PnL.
#' - total_equities_balance (numeric | NA) total equities balance.
NULL
