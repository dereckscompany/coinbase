# Generate a Client Order ID

Produces a random RFC 4122 version-4 UUID string for use as the
`client_order_id` idempotency key when placing orders.

## Usage

``` r
generate_client_order_id()
```

## Value

Character; a UUID, e.g. `"11299b2b-61e3-43e7-b9f7-dee77210bb29"`.

## Examples

``` r
generate_client_order_id()
#> [1] "1bbf4781-a308-45ed-a1b6-c809eb523718"
```
