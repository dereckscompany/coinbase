# Convert a Coinbase Timestamp to POSIXct

Coinbase returns times in two forms: ISO 8601 strings (most endpoints)
and epoch seconds (the Exchange candle bounds). This converts either
form to a POSIXct in UTC.

## Usage

``` r
time_convert_from_coinbase(time_value, unit = c("iso", "s"))
```

## Arguments

- time_value:

  Character ISO 8601 timestamp(s), or numeric epoch seconds.

- unit:

  Character; the input form: `"iso"` (ISO 8601 string, default) or `"s"`
  (epoch seconds).

## Value

POSIXct vector in UTC.

## Examples

``` r
if (FALSE) { # \dontrun{
time_convert_from_coinbase("2026-05-31T18:40:29Z")
time_convert_from_coinbase(1780203360, unit = "s")
} # }
```
