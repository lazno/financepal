CREATE TABLE IF NOT EXISTS asset_registry (
  isin TEXT PRIMARY KEY,
  symbol TEXT NOT NULL,
  instrument_type TEXT NOT NULL,
  asset_name TEXT NOT NULL
);

CREATE INDEX idx_asset_registry_symbol ON asset_registry(symbol);
