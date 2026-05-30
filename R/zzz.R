# Suppress R CMD check notes for data.table non-standard evaluation.
utils::globalVariables(c(
  ".N",
  ".SD",
  ":=",
  # OHLCV / aggregation columns
  "datetime",
  "open",
  "high",
  "low",
  "close",
  "volume",
  "price",
  "size",
  # Trade columns
  "trade_id",
  "time"
))
