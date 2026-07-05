# Build and Execute a Coinbase API Request

Constructs an
[httr2::request](https://httr2.r-lib.org/reference/request.html),
optionally JWT-signs it, performs it (sync or async), and parses the
Coinbase response envelope. This is the single point through which all
Coinbase API calls flow; it is a thin Coinbase-specific wrapper over
[`connectcore::build_request()`](https://rdrr.io/pkg/connectcore/man/build_request.html)
that injects the two seams that differ per venue — JWT signing (the
internal `coinbase_jwt_sign()`) and the Coinbase error/empty-body
envelope (the internal `parse_coinbase_response()`). Everything else
(the sync/async branch, NULL-field stripping, the JSON body, retry,
throttle) comes from connectcore.

## Usage

``` r
coinbase_build_request(
  base_url,
  endpoint,
  method = "GET",
  query = list(),
  body = NULL,
  keys = NULL,
  .perform = httr2::req_perform,
  .parser = identity,
  is_async = FALSE,
  timeout = 30
)
```

## Arguments

- base_url:

  (scalar\<character\>) the API base URL (scheme + host).

- endpoint:

  (scalar\<character\>) the API path.

- method:

  (scalar\<character\>) HTTP method. Default `"GET"`.

- query:

  (list) query parameters. Default
  [`list()`](https://rdrr.io/r/base/list.html).

- body:

  (list \| NULL) request body. Default `NULL`.

- keys:

  (list \| NULL) API credentials. When non-NULL the request is signed.
  Default `NULL`.

- .perform:

  (function) the httr2 perform function. Default
  [`httr2::req_perform`](https://httr2.r-lib.org/reference/req_perform.html).

- .parser:

  (function) post-processing applied to the parsed response body.
  Default `identity`.

- is_async:

  (scalar\<logical\>) whether `.perform` returns promises. Default
  `FALSE`.

- timeout:

  (scalar\<numeric in \]0, Inf\[\>) request timeout in seconds. Default
  `30`.

## Value

(any \| promise\<any\>) parsed and post-processed API response data, or
a promise thereof.

## Details

### Sync vs Async

The `.perform` argument controls execution mode:

- [`httr2::req_perform`](https://httr2.r-lib.org/reference/req_perform.html)
  (default): synchronous, returns the parsed data.

- [`httr2::req_perform_promise`](https://httr2.r-lib.org/reference/req_perform_promise.html):
  asynchronous, returns a
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html).
