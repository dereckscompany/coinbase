# coinbase 0.2.1

## Shared mock test harness + real captured fixtures

* The hand-rolled mock HTTP router is gone. `tests/testthat/mock_router.R` no
  longer carries its own response builder and dispatch loop; it now declares
  only the route table (`.mock_routes`) and resolves the dispatcher from
  [connectcore](https://github.com/dereckscompany/connectcore) (`>= 0.2.0`),
  whose shared harness (`mock_router()`, `with_mock_api()`, `local_mock_api()`,
  `load_fixtures()`, `mock_response()`) every connector now reuses. Tests and the
  README/vignette setup chunks install the mock with
  `connectcore::local_mock_api(.mock_routes)` instead of hand-setting
  `options(httr2_mock = ...)`. The hand-written fixture file
  `tests/testthat/helper-mockery.R` was deleted. Together this drops roughly 270
  lines of duplicated mock machinery.
* The test fixtures are now **real captured Coinbase responses**, stored as
  `tests/testthat/fixtures/*.json` and served verbatim, so the parsers and
  column contracts are validated against genuine exchange data rather than
  hand-modelled shapes. The authenticated fixtures are **scrubbed**: every real
  account/portfolio/order UUID is replaced with a deterministic synthetic UUID
  and every balance/amount/price/fee with a round synthetic value, while the
  exact JSON shape — every field, type, and nesting level — is preserved.
  Public market-data fixtures are verbatim. The few endpoints the live test
  account cannot populate (it holds no derivatives positions and a spot-only
  portfolio) and the write endpoints that must never be exercised
  (order create/preview/edit/cancel/close, sweep schedule/cancel) keep a
  representative hand-written fixture so their populated column contracts stay
  covered. The full suite passes against the real data with no contract
  changes.

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
* Typed `data.table` return shapes are now the single source of truth for what
  every table-returning method yields. `R/types_coinbase.R` defines reusable
  roxyassert `@type` shapes (`Ohlcv`, `Trades`, `Accounts`, `Orders`, `Fills`,
  `Preview`, `CreateOrderAck`, the futures shapes, ...), each typed column by
  column to what the parser actually produces. A fixed-shape method documents
  its result as `(Shape | promise<Shape>)`, so the contract roclet expands the
  shape into the method's `assert_return_*` and every column's presence and type
  is checked at the public boundary; the variable-shape methods (order book,
  portfolio breakdown, and the generic acks) keep `(data.table |
  promise<data.table>)`.
* `assert_return` is now enforced at every table-returning method, sync and
  async alike, by wrapping the result in `connectcore::then_or_now(res, ...)` —
  the single sync/async branch point — so the resolved value is validated in
  both modes without touching the async path.
* So that an empty result still satisfies its column contract, each fixed-shape
  parser's empty branch now returns a fully-typed zero-row table (`empty_dt_*()`
  in `R/helpers_parse.R`, one per shape) instead of a schemaless `data.table()`;
  datetime columns
  are built with the same `iso_to_datetime()` / `s_to_datetime()` helpers the
  populated path uses so class and tz match.
* Adopted the `R/imports.R` convention (`@import assert` / `data.table` /
  `promises`), replacing the `_PACKAGE` doc file, to match the sibling
  connectors.

## Review-round hardening

* **Non-empty string identifiers.** roxyassert's grammar has no non-empty-string
  production (`scalar<character>` accepts `""`), so every required string that
  identifies a resource — account / portfolio / order ids, the
  `client_order_id` idempotency key, futures `setting` / `margin_profile_type`,
  request `base_url` / `endpoint` / `host` / `path`, the private key — now
  carries an explicit `assert::assert_nonempty_strings()` guard, and every
  optional id / code filter (`currency`, `product_type`, the `*_id(s)` filters,
  `leverage`, `margin_type`) uses the same guard with `null_ok = TRUE`. The
  `coinbase_backfill_trades(file = )` guard now also rejects the empty path.
* **Tighter `any` annotations.** `datetime_to_epoch()` is now typed
  `(POSIXct | Date | NULL)` and `load_private_key()` returns `(class<key>)`
  instead of `(any)`. The raw-JSON value helpers (`num_or_na()`, `flex_num()`,
  `money_value()`) keep `any` because the underlying value's R type genuinely
  varies (integer / double / character / logical); `nth_num()` / `nth_chr()`
  are tightened to `(list | vector<any, 0..> | NULL)`.
* **Documented lossy rounding.** `datetime_to_epoch()` and
  `time_convert_to_coinbase(unit = "s")` now state in their docs that the value
  is **floored** to the whole second (sub-second precision truncated towards the
  past, not rounded); `trades_to_ohlcv()` documents that each trade is floored
  to its left-closed bar start.
* **`generate_client_order_id()`** now delegates to `uuid::UUIDgenerate()` (added
  to Imports) instead of hand-rolling the RFC-4122 v4 bit-twiddling; the output
  is the same standard 36-character hyphenated UUID Coinbase accepts.
* **No exported shape validators.** The `@type` shapes block in
  `R/types_coinbase.R` no longer carries `@genassert` / `@exportassert`. coinbase
  is a leaf connector: nothing internal calls a per-shape `assert_type_<Shape>()`
  and no downstream package validates against these shapes, so generating and
  exporting 21 standalone validators only polluted the `NAMESPACE` (and forced a
  `man/roxyassert-generated-asserts.Rd`). Both are removed. Each shape is still
  expanded inline into its method's `assert_return_*` via the `@return`
  `(Shape | promise<Shape>)` reference, so every column is still enforced at the
  public boundary — that path is unchanged.

## Self-review fixes

* **`promises` is now a hard dependency.** `R/imports.R` declares
  `@import promises` (so `NAMESPACE` has `import(promises)`) and
  `promises::then()` is called unconditionally in `R/helpers_paginate.R` and
  `R/impl_trades.R`, so `promises` belongs in `Imports`, not `Suggests` (where
  it triggered an `R CMD check` "Namespace dependency not required" warning). It
  has been moved.
* **A genuinely empty deep-trade fetch keeps the `Trades` contract.** The
  empty-accumulator branch of `coinbase_fetch_trades_history()` returned a bare
  schemaless `data.table()`, which `get_trades_history()`'s generated
  `assert_return` (the 5-column `Trades` shape) would reject — so an empty fetch
  through the public method aborted. It now returns the fully-typed zero-row
  `empty_dt_trades()`, and the empty-universe test drives the public
  `get_trades_history()` (not the bare impl) and asserts the five `Trades`
  columns are present and correctly typed.
* **The `Products` shape is now wired to a method.** `get_products()` previously
  returned a bare `(data.table)` via `as_dt_list`, leaving the `Products`
  `@type` referenced by no method (and the types prose's "every shape is
  referenced by a method's `@return`" claim false). The live Exchange
  `/products` payload is a fixed 18-field record, so a `parse_products()` (with
  `empty_dt_products()`) now builds the typed `Products` table, `get_products()`
  uses it as its `.parser`, and its `@return` is `(Products | promise<Products>)`
  — every column enforced at the public boundary, the prose claim now true.

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
