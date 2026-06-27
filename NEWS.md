# coinbase (development version)

## Transport migration to connectcore

* The HTTP transport now builds on
  [connectcore](https://github.com/dereckscompany/connectcore) (`v0.0.1`), the
  shared transport base extracted from these connectors. `CoinbaseBase` inherits
  `connectcore::RestClient` and overrides only the two genuinely
  Coinbase-specific seams — `.sign()` (the ES256 / EdDSA JWT) and
  `.parse_envelope()` (the Coinbase error envelope and tolerated empty success
  bodies). The single `private$.request()` funnel, the sync/async branch
  (`then_or_now()`), `NULL`-field stripping, and the optional retry/throttle now
  come from connectcore.
* `coinbase_build_request()` is retained, with its signature and behaviour
  unchanged, as a thin wrapper that wires the two Coinbase seams into
  `connectcore::build_request()`. The hand-rolled httr2 request plumbing and the
  duplicated `then_or_now()` it used to carry are deleted.
* The dual-host design (Advanced Trade vs. Exchange) is preserved: `.request()`
  extends the connectcore funnel with a per-request `base_url` argument.
* The public API (R6 classes, exported functions, and return shapes) is
  unchanged.

# coinbase 0.0.1

Initial release: an R wrapper for the Coinbase Advanced Trade API, supporting
both synchronous and asynchronous (promise-based) operations.

## Features

* **Market data** (`CoinbaseMarketData`, public, no auth): products, OHLCV
  candles, tick trades, order book (levels 1-3), ticker, and server time over
  the Coinbase Exchange host.
* **Deep tick history**: `CoinbaseMarketData$get_trades_history()` and the
  standalone `coinbase_backfill_trades()` walk the trades endpoint back to a
  product's inception, with incremental CSV writes and resume. Aggregate ticks
  into OHLCV at any timeframe with `trades_to_ohlcv()`.
* **Account** (`CoinbaseAccount`): accounts/balances (cursor-paginated), fee
  tier, portfolios (with `get_portfolio_breakdown()` stacking spot/futures/perp
  positions and `get_portfolio_summary()` for the totals), and key permissions.
* **Trading** (`CoinbaseTrading`): place, preview (dry run), edit, cancel, close
  (`close_position()`), and query orders and fills.
* **US futures / CFM** (`CoinbaseFutures`): balance summary, positions, margin
  settings, and cash sweeps for the short leg of pairs strategies. Futures
  orders are placed through the shared order endpoint with a futures product.

## Design

* Every public method returns a `data.table` with no list columns.
* Authentication uses a per-request ES256 (EC) or EdDSA (Ed25519) JWT; the
  `uri` claim excludes the query string. Credentials come from the
  `COINBASE_API_KEY_NAME` / `COINBASE_API_PRIVATE_KEY` environment variables.
* All requests flow through a single funnel (`coinbase_build_request()`) with
  one sync/async branch point.
* Inputs are validated with the `assert` package; times are handled in UTC via
  `lubridate`. Money values are transmitted with exact precision.
