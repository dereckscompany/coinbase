# Retrieve Coinbase Exchange API Base URL

Returns the base URL for the Coinbase Exchange API in the following
priority:

1.  The explicitly provided `url` parameter.

2.  The `COINBASE_EXCHANGE_API_ENDPOINT` environment variable.

3.  The default `"https://api.exchange.coinbase.com"`.

## Usage

``` r
get_exchange_base_url(url = Sys.getenv("COINBASE_EXCHANGE_API_ENDPOINT"))
```

## Arguments

- url:

  Character string; explicit base URL. Defaults to
  `Sys.getenv("COINBASE_EXCHANGE_API_ENDPOINT")`.

## Value

Character string; the Exchange API base URL.

## Details

The Exchange API hosts the public market-data endpoints (e.g. full trade
history paginated back to a product's inception) that the Advanced Trade
host does not expose. These endpoints require no authentication.

## Examples

``` r
if (FALSE) { # \dontrun{
get_exchange_base_url()
} # }
```
