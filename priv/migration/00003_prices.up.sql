CREATE TABLE IF NOT EXISTS prices (
  id TEXT PRIMARY KEY, 
  isin TEXT NOT NULL,
  price REAL NOT NULL,
  currency TEXT NOT NULL,
  fetched_at REAL NOT NULL
);

CREATE INDEX idx_prices_isin ON prices(isin);
