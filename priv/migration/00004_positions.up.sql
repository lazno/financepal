CREATE TABLE IF NOT EXISTS positions (
  isin TEXT PRIMARY KEY,
  symbol TEXT NOT NULL,
  asset_name TEXT NOT NULL,
  quantity REAL NOT NULL
);

CREATE INDEX idx_position_symbol ON positions(symbol);
