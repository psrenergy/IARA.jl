PRAGMA user_version = 16;
PRAGMA foreign_keys = ON;

ALTER TABLE BiddingGroup ADD COLUMN fixed_cost REAL NOT NULL DEFAULT 0.0;
