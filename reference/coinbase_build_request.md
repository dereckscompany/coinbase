# Build and Execute a Coinbase API Request

Constructs an
[httr2::request](https://httr2.r-lib.org/reference/request.html),
optionally attaches a signed JWT, performs it via the supplied
`.perform` function, and parses the JSON response. This is the single
point through which all Coinbase API calls flow.

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

  Character; the API base URL (scheme + host).

- endpoint:

  Character; the API path.

- method:

  Character; HTTP method. Default `"GET"`.

- query:

  Named list; query parameters. Default
  [`list()`](https://rdrr.io/r/base/list.html).

- body:

  Named list or NULL; request body. Default `NULL`.

- keys:

  List or NULL; API credentials. When non-NULL the request is signed.
  Default `NULL`.

- .perform:

  Function; the httr2 perform function. Default
  [`httr2::req_perform`](https://httr2.r-lib.org/reference/req_perform.html).

- .parser:

  Function; post-processing applied to the parsed response body. Default
  `identity`.

- is_async:

  Logical; whether `.perform` returns promises. Default `FALSE`.

- timeout:

  Numeric; request timeout in seconds. Default `30`.

## Value

Parsed and post-processed API response data, or a promise thereof.

## Details

### Sync vs Async

The `.perform` argument controls execution mode:

- [`httr2::req_perform`](https://httr2.r-lib.org/reference/req_perform.html)
  (default): synchronous, returns an
  [httr2::response](https://httr2.r-lib.org/reference/response.html).

- [`httr2::req_perform_promise`](https://httr2.r-lib.org/reference/req_perform_promise.html):
  asynchronous, returns a
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html).
