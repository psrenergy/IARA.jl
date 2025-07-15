PRAGMA user_version = 17;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN price_limits INTEGER NOT NULL DEFAULT 0;
