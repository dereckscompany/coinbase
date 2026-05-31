# Daily OHLCV Sample Data from Coinbase

Historical daily candlestick (OHLCV) data for three major spot pairs
(`"BTC-USD"`, `"ETH-USD"`, `"SOL-USD"`) from the Coinbase Exchange API,
stacked into a single long table with a `symbol` column. Roughly 350
daily candles per product, included for demonstration and examples.
Produced with
[CoinbaseMarketData](https://dereckscompany.github.io/coinbase/reference/CoinbaseMarketData.md)'s
`get_ohlcv()` method.

## Usage

``` r
coinbase_ohlcv
```

## Format

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with 1,050 rows and 7 columns:

- `symbol` (Character): Trading pair identifier, e.g. `"BTC-USD"`.

- `datetime` (POSIXct): Candle start time in UTC.

- `open` (Numeric): Opening price.

- `high` (Numeric): Highest price during the interval.

- `low` (Numeric): Lowest price during the interval.

- `close` (Numeric): Closing price.

- `volume` (Numeric): Trading volume in base currency.

## Source

Coinbase Exchange API via `CoinbaseMarketData$get_ohlcv()`

## Examples

``` r
data(coinbase_ohlcv)
head(coinbase_ohlcv)
#>     symbol   datetime     open     high      low    close   volume
#>     <char>     <POSc>    <num>    <num>    <num>    <num>    <num>
#> 1: BTC-USD 2025-06-16 105600.2 109000.0 104982.3 106853.4 5952.984
#> 2: BTC-USD 2025-06-17 106853.4 107792.9 103363.3 104590.4 7688.946
#> 3: BTC-USD 2025-06-18 104590.4 105603.6 103512.4 104915.6 4918.144
#> 4: BTC-USD 2025-06-19 104915.6 105266.6 103916.4 104671.9 2279.058
#> 5: BTC-USD 2025-06-20 104671.4 106553.9 102357.2 103317.8 5047.636
#> 6: BTC-USD 2025-06-21 103317.8 104013.6 100919.2 102160.0 3287.513
```
