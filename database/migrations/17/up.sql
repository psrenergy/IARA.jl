PRAGMA user_version = 17;
PRAGMA foreign_keys = ON;

ALTER TABLE BiddingGroup ADD COLUMN fixed_cost REAL NOT NULL DEFAULT 0.0;
