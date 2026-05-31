# Extracted from test-backfill.R:26

# test -------------------------------------------------------------------------
expect_error(coinbase_backfill_trades("BTCUSD", file = tempfile()), "Invalid product_id")
