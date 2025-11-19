CREATE TABLE IF NOT EXISTS policy (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  targets JSON NOT NULL,
  sensitivity JSON NOT NULL,
  min_trade_value REAL NOT NULL,
  turnover_cap INTEGER NOT NULL
);
