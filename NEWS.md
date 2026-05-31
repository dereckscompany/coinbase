# coinbase 0.0.0.9000

Initial development version: an R wrapper for the Coinbase Advanced Trade API,
supporting both synchronous and asynchronous (promise-based) operations.

## Features

* **Market data** (`CoinbaseMarketData`, public, no auth): products, OHLCV
  candles, tick trades, order book (levels 1-3), ticker, and server time over
  the Coinbase Exchange host.
* **Deep tick history**: `CoinbaseMarketData$get_trades_history()` and the
  standalone `coinbase_backfill_trades()` walk the trades endpoint back to a
  product's inception, with incremental CSV writes and resume. Aggregate ticks
  into OHLCV at any timeframe with `trades_to_ohlcv()`.
* **Account** (`CoinbaseAccount`): accounts/balances (cursor-paginated), fee
  tier, portfolios, and key permissions.
* **Trading** (`CoinbaseTrading`): place, preview (dry run), edit, cancel, and
  query orders and fills.
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
