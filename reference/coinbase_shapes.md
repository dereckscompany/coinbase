# Coinbase return shapes

Reusable roxyassert `@type` shapes for the parsed Coinbase
`data.table`s. Every column is typed to what the parser actually
produces: `numeric` is the strict double (the package convention); a
column is marked `| NA` wherever the parser can emit a missing value –
which is most of them, because the parsers coalesce absent JSON fields
to `NA` (`num_or_na`, `coalesce_null(.., NA_character_)`,
`iso_to_datetime` on a missing string) and the field may legitimately be
absent in a real response. So that an empty result still satisfies its
contract, each parser's empty branch returns the fully-typed zero-row
table for its shape (see `empty_dt_*()` in R/helpers_parse.R) rather
than a bare schemaless `data.table()`.

Shapes: `Products`, `Ohlcv`, `Trades`, `Stats`, `ProductStats`,
`BestBidAsk`, `Accounts`, `Fees`, `OrderConfig` (the flattened
`order_configuration` record), `Orders`, `Fills`, `Preview`,
`CreateOrderAck`, `EditOrderAck`, `EditPreview`, `CancelResults`,
`MarginWindow`, `FuturesBalance`, `FuturesPositions`, `FuturesSweeps`,
`PortfolioSummary`. The order book (`parse_orderbook`) and the portfolio
breakdown (`parse_portfolio_breakdown`) return level/source-dependent
column sets and are documented inline at those parsers.

Each shape is referenced by a table-returning method's `@return` as
`(Shape | promise<Shape>)`, so the contract roclet expands it inline
into that method's generated `assert_return_*` – no standalone
`assert_type_<Shape>()` is emitted. coinbase is a leaf connector:
nothing internal calls a per-shape validator and no downstream package
validates against these shapes, so there is no `@genassert` (no callable
validators to generate) and no `@exportassert` (nothing to export).
