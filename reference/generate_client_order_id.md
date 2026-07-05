# Generate a Client Order ID

Produces a random RFC 4122 version-4 UUID string for use as the
`client_order_id` idempotency key when placing orders. Delegates to
[`uuid::UUIDgenerate()`](https://rdrr.io/pkg/uuid/man/UUIDgenerate.html),
whose output is the standard 36-character hyphenated UUID that Coinbase
accepts.

## Usage

``` r
generate_client_order_id()
```

## Value

(scalar\<character\>) a UUID, e.g.
`"11299b2b-61e3-43e7-b9f7-dee77210bb29"`.

## Examples

``` r
generate_client_order_id()
#> [1] "71ea68bb-a6ef-458b-bbda-3db45cf6f711"
```
