# Verify a Coinbase Product Symbol

Checks whether a symbol is a dash-separated alphanumeric product ID.
This covers spot pairs (`"BTC-USD"`) as well as the multi-segment
expiring-futures IDs CFM uses (`"BIT-28FEB25-CDE"`) — anything with at
least two segments joined by single dashes.

## Usage

``` r
verify_symbol(product_id)
```

## Arguments

- product_id:

  Character string; the symbol to verify.

## Value

Logical; `TRUE` if valid, `FALSE` otherwise.

## Examples

``` r
verify_symbol("BTC-USD") # TRUE
#> [1] TRUE
verify_symbol("BIT-28FEB25-CDE") # TRUE
#> [1] TRUE
verify_symbol("BTCUSD") # FALSE
#> [1] FALSE
```
