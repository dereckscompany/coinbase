# Retrieve Coinbase Advanced Trade API Base URL

Returns the base URL for the Coinbase Advanced Trade API (trading,
account, and authenticated endpoints) in the following priority:

1.  The explicitly provided `url` parameter.

2.  The `COINBASE_API_ENDPOINT` environment variable.

3.  The default `"https://api.coinbase.com"`.

## Usage

``` r
get_base_url(url = Sys.getenv("COINBASE_API_ENDPOINT"))
```

## Arguments

- url:

  Character string; explicit base URL. Defaults to
  `Sys.getenv("COINBASE_API_ENDPOINT")`.

## Value

Character string; the API base URL.

## Examples

``` r
if (FALSE) { # \dontrun{
get_base_url()
} # }
```
