# Convert a POSIXct to a Coinbase Timestamp

Formats a POSIXct as the timestamp form Coinbase expects: an ISO 8601
string (`"iso"`, default) or whole-number epoch seconds (`"s"`, used for
the Exchange candle bounds).

## Usage

``` r
time_convert_to_coinbase(datetime, unit = c("iso", "s"))
```

## Arguments

- datetime:

  (POSIXct) object(s) to convert.

- unit:

  (scalar\<character in c("iso", "s")\>) the output form: `"iso"`
  (default) or `"s"`.

## Value

(character \| numeric) an ISO 8601 timestamp (`"iso"`) or numeric epoch
seconds (`"s"`).

## Details

For `unit = "s"` the value is **floored** to the whole second
(sub-second precision is truncated towards the past, not rounded); the
`"iso"` form is likewise formatted to whole-second resolution (`%S`
drops fractional seconds).

## Examples

``` r
if (FALSE) { # \dontrun{
dt <- lubridate::as_datetime("2026-05-31 18:40:29", tz = "UTC")
time_convert_to_coinbase(dt)            # "2026-05-31T18:40:29Z"
time_convert_to_coinbase(dt, unit = "s") # 1780252829
} # }
```
