# coinbase 0.2.0

## Runtime contracts via roxyassert

* Every `@param` and `@return` across the package is now written in the
  [roxyassert](https://github.com/dereckscompany/roxyassert) (`v0.9.1`) type
  grammar, and the `roxyassert::contract_roclet` generates the matching runtime
  assertions into `R/contracts-generated.R`. Each function and R6 method now
  validates its inputs (`assert_args_*`) and, where a concrete `@return` type is
  declared, its result (`assert_return_*`) against its documented contract — so
  the documentation and the runtime check come from one source.
* No public signature or behaviour changed for valid inputs: the contracts
  accept exactly what the previous hand-written `assert::` guards and the test
  suite already passed. The pre-existing inline `assert::` checks were folded
  into the generated contracts where the grammar expresses them; the residual
  guards the grammar cannot express (the `BASE-QUOTE` symbol regex, the
  single-key order-configuration shape, the positive-finite money coercion, the
  granularity / order-book-level enums with their bespoke error messages) are
  kept as explicit guards, with the corresponding parameters marked `@noassert`
  so they are documented but not double-validated.
* Sync-or-async endpoint results are typed `(data.table | promise<data.table>)`
  for documentation; following connectcore, the promise-returning method bodies
  are left unwrapped so the async path is unaffected.

# coinbase 0.1.0

## Transport migration to connectcore

* The HTTP transport now builds on
  [connectcore](https://github.com/dereckscompany/connectcore) (`v0.1.0`), the
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
* Pinned to connectcore `v0.1.0`, which restores multi-value query support
  (`.multi = "explode"`) in the funnel: a vector `product_ids` now repeats the
  key (`?product_ids=A&product_ids=B`) instead of aborting, as Coinbase's
  `best_bid_ask`, `orders`, and `fills` endpoints require. Added a network-free
  regression test that pins this behaviour.

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
