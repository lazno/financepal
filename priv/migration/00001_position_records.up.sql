
CREATE TABLE IF NOT EXISTS position_records (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  symbol TEXT NOT NULL,
  isin TEXT NOT NULL,
  asset_name TEXT NOT NULL,
  type TEXT NOT NULL,
  quantity REAL NOT NULL,
  account TEXT NOT NULL,
  order_reference TEXT NOT NULL,
  inserted_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_position_records_symbol ON position_records(symbol);
CREATE INDEX idx_position_records_order_reference ON position_records(order_reference);
