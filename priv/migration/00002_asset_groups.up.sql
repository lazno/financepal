
CREATE TABLE IF NOT EXISTS asset_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  parent_group_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (parent_group_id) REFERENCES asset_groups(id)
);

CREATE TABLE IF NOT EXISTS asset_group_members (
  symbol TEXT NOT NULL,
  group_id INTEGER NOT NULL,
  PRIMARY KEY (symbol, group_id),
  FOREIGN KEY (group_id) REFERENCES asset_groups(id) ON DELETE CASCADE
);
