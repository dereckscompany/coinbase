# CoinbaseBase: Abstract Base Class for Coinbase API Clients

CoinbaseBase: Abstract Base Class for Coinbase API Clients

CoinbaseBase: Abstract Base Class for Coinbase API Clients

## Details

Provides shared infrastructure for all Coinbase R6 classes by extending
[connectcore::RestClient](https://dereckscompany.github.io/connectcore/reference/RestClient.html).
It inherits the single `private$.request()` funnel (mode-transparent
sync/async, NULL-field stripping, retry/throttle) and customises only
the two venue-specific seams:

- `.sign()` — attaches a Coinbase JWT (ES256 / EdDSA) to each
  authenticated request (via the internal `coinbase_jwt_sign()`).

- `.parse_envelope()` — reads the Coinbase error envelope and tolerates
  the empty success bodies some endpoints return (via the internal
  `parse_coinbase_response()`).

### Sync vs Async

The `async` parameter controls execution mode for all API methods:

- `async = FALSE` (default): methods return results directly.

- `async = TRUE`: methods return
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html)
  objects that resolve to the same types.

Async mode requires the `promises` package (a `Suggests`). Consume
promises with
[`coro::async()`](https://coro.r-lib.org/reference/async.html) and
`await()` or
[`promises::then()`](https://rstudio.github.io/promises/reference/then.html);
to drive the event loop in a script use the (optional) `later` package,
e.g. `while (!later::loop_empty()) later::run_now()`.

### Hosts

Coinbase splits across two hosts. Authenticated trading and account
endpoints live on the Advanced Trade host
([`get_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_base_url.md),
`https://api.coinbase.com`); the public market-data endpoints with deep
history live on the Exchange host
([`get_exchange_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_exchange_base_url.md),
`https://api.exchange.coinbase.com`). Subclasses select the host per
request via the `base_url` argument of `private$.request()` (this class
extends the connectcore funnel with that argument).

### Retries

`max_tries > 1` opts every GET this client makes — single requests and
cursor-paginated reads alike — into automatic retry on a transient
failure (HTTP 408/429/5xx or a dropped connection) with jittered
backoff, delegated to
[`connectcore::build_request()`](https://dereckscompany.github.io/connectcore/reference/build_request.html).
Retry is a hard **GET-only** carve-out: a non-idempotent verb (an order
`POST`, a cancel `DELETE`) is never auto-retried, so a resend can never
double-submit an order. Coinbase's own intermittent `401`s while a fresh
API key propagates are *not* retried (a 401 is not in the transient
set). Leave it at the default `1` for live trading — there the trader
layer is the single retry authority (it routes by typed error class and
manages cooldowns); raise it only for research and backfill reads.

### Design

This class is not meant to be instantiated directly. Subclasses (e.g.
`CoinbaseMarketData`, `CoinbaseTrading`) inherit from it and define
public methods that delegate to `private$.request()`.

## Fields

All fields are private:

- `.exchange_base_url`: Character; Exchange API base URL (the Advanced
  Trade base, credentials, async flag, and perform function are held by
  the
  [connectcore::RestClient](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
  superclass).

## Super class

[`connectcore::RestClient`](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
-\> `CoinbaseBase`

## Methods

### Public methods

- [`CoinbaseBase$new()`](#method-CoinbaseBase-new)

- [`CoinbaseBase$clone()`](#method-CoinbaseBase-clone)

------------------------------------------------------------------------

### Method `new()`

Initialise a CoinbaseBase object.

#### Usage

    CoinbaseBase$new(
      keys = get_api_keys(),
      base_url = get_base_url(),
      exchange_base_url = get_exchange_base_url(),
      async = FALSE,
      max_tries = 1L
    )

#### Arguments

- `keys`:

  (list \| NULL) API credentials from
  [`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md).
  Defaults to
  [`get_api_keys()`](https://dereckscompany.github.io/coinbase/reference/get_api_keys.md).

- `base_url`:

  (scalar\<character\>) Advanced Trade API base URL. Defaults to
  [`get_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_base_url.md).

- `exchange_base_url`:

  (scalar\<character\>) Exchange API base URL. Defaults to
  [`get_exchange_base_url()`](https://dereckscompany.github.io/coinbase/reference/get_exchange_base_url.md).

- `async`:

  (scalar\<logical\>) if `TRUE`, methods return promises. Default
  `FALSE`.

- `max_tries`:

  (scalar\<integer in \[1, 10\]\>) for idempotent GET requests only,
  retry up to this many times on a transient failure. Default `1` (no
  retry). See the class **Retries** section for the write-safety
  carve-out and why live trading should leave this at `1`.

#### Returns

(class\<CoinbaseBase\>) invisibly, self.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    CoinbaseBase$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
