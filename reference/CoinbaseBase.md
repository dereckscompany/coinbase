# CoinbaseBase: Abstract Base Class for Coinbase API Clients

Provides shared infrastructure for all Coinbase R6 classes, including
API credential management, sync/async execution mode, and a standardised
method for executing API requests through the single
[`coinbase_build_request()`](https://dereckscompany.github.io/coinbase/reference/coinbase_build_request.md)
funnel.

### Sync vs Async

The `async` parameter controls execution mode for all API methods:

- `async = FALSE` (default): methods return results directly.

- `async = TRUE`: methods return
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html)
  objects that resolve to the same types.

Async mode requires the `promises` and `later` packages (both
`Suggests`). Consume promises with
[`coro::async()`](https://coro.r-lib.org/reference/async.html) and
`await()` or
[`promises::then()`](https://rstudio.github.io/promises/reference/then.html),
and drive the event loop with
[`later::run_now()`](https://later.r-lib.org/reference/run_now.html)
(e.g. `while (!later::loop_empty()) later::run_now()`).

### Hosts

Coinbase splits across two hosts. Authenticated trading and account
endpoints live on the Advanced Trade host
([`get_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_base_url.md),
`https://api.coinbase.com`); the public market-data endpoints with deep
history live on the Exchange host
([`get_exchange_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_exchange_base_url.md),
`https://api.exchange.coinbase.com`). Subclasses select the host per
request via the `base_url` argument of `private$.request()`.

### Design

This class is not meant to be instantiated directly. Subclasses (e.g.
`CoinbaseMarketData`, `CoinbaseTrading`) inherit from it and define
public methods that delegate to `private$.request()`.

## Fields

All fields are private:

- `.keys`: List; API credentials from
  [`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md).

- `.base_url`: Character; Advanced Trade API base URL.

- `.exchange_base_url`: Character; Exchange API base URL.

- `.perform`: Function; either
  [httr2::req_perform](https://httr2.r-lib.org/reference/req_perform.html)
  or
  [httr2::req_perform_promise](https://httr2.r-lib.org/reference/req_perform_promise.html).

- `.is_async`: Logical; whether the instance is in async mode.

## Active bindings

- `is_async`:

  Logical; read-only flag indicating whether this instance operates in
  async mode.

## Methods

### Public methods

- [`CoinbaseBase$new()`](#method-CoinbaseBase-initialize)

- [`CoinbaseBase$clone()`](#method-CoinbaseBase-clone)

------------------------------------------------------------------------

### `CoinbaseBase$new()`

Initialise a CoinbaseBase object.

#### Usage

    CoinbaseBase$new(
      keys = get_api_keys(),
      base_url = get_base_url(),
      exchange_base_url = get_exchange_base_url(),
      async = FALSE
    )

#### Arguments

- `keys`:

  List; API credentials from
  [`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md).
  Defaults to
  [`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md).

- `base_url`:

  Character; Advanced Trade API base URL. Defaults to
  [`get_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_base_url.md).

- `exchange_base_url`:

  Character; Exchange API base URL. Defaults to
  [`get_exchange_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_exchange_base_url.md).

- `async`:

  Logical; if `TRUE`, methods return promises. Default `FALSE`.

#### Returns

Invisible self.

------------------------------------------------------------------------

### `CoinbaseBase$clone()`

The objects of this class are cloneable with this method.

#### Usage

    CoinbaseBase$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
