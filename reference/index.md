# Package index

## API Client Classes

R6 classes for interacting with the Coinbase API

- [`CoinbaseBase`](https://dereckscompany.github.io/coinbase/reference/CoinbaseBase.md)
  : CoinbaseBase: Abstract Base Class for Coinbase API Clients
- [`CoinbaseMarketData`](https://dereckscompany.github.io/coinbase/reference/CoinbaseMarketData.md)
  : CoinbaseMarketData: Public Market Data Retrieval
- [`CoinbaseAccount`](https://dereckscompany.github.io/coinbase/reference/CoinbaseAccount.md)
  : CoinbaseAccount: Account, Balance, and Fee Information
- [`CoinbaseTrading`](https://dereckscompany.github.io/coinbase/reference/CoinbaseTrading.md)
  : CoinbaseTrading: Order Placement and Management
- [`CoinbaseFutures`](https://dereckscompany.github.io/coinbase/reference/CoinbaseFutures.md)
  : CoinbaseFutures: US Futures (CFM) Account, Positions, and Margin

## Configuration

API credential and endpoint helpers

- [`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md)
  : Retrieve Coinbase API Credentials
- [`get_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_base_url.md)
  : Retrieve Coinbase Advanced Trade API Base URL
- [`get_exchange_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_exchange_base_url.md)
  : Retrieve Coinbase Exchange API Base URL
- [`generate_client_order_id()`](https://dereckscompany.github.io/coinbase/reference/generate_client_order_id.md)
  : Generate a Client Order ID

## Low-Level Request Helpers

Functions for building Coinbase API requests

- [`coinbase_build_request()`](https://dereckscompany.github.io/coinbase/reference/coinbase_build_request.md)
  : Build and Execute a Coinbase API Request
- [`verify_symbol()`](https://dereckscompany.github.io/coinbase/reference/verify_symbol.md)
  : Verify a Coinbase Product Symbol

## Backfill and Data

Bulk data download, tick aggregation, and included datasets

- [`coinbase_backfill_trades()`](https://dereckscompany.github.io/coinbase/reference/coinbase_backfill_trades.md)
  : Backfill Coinbase Trade History to CSV
- [`trades_to_ohlcv()`](https://dereckscompany.github.io/coinbase/reference/trades_to_ohlcv.md)
  : Aggregate Tick Trades into OHLCV Bars
- [`coinbase_ohlcv`](https://dereckscompany.github.io/coinbase/reference/coinbase_ohlcv.md)
  : Daily OHLCV Sample Data from Coinbase

## Utilities

Time conversion helpers

- [`time_convert_from_coinbase()`](https://dereckscompany.github.io/coinbase/reference/time_convert_from_coinbase.md)
  : Convert a Coinbase Timestamp to POSIXct
- [`time_convert_to_coinbase()`](https://dereckscompany.github.io/coinbase/reference/time_convert_to_coinbase.md)
  : Convert a POSIXct to a Coinbase Timestamp
