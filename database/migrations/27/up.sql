PRAGMA user_version = 27;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN virtual_reservoir_residual_revenue_split_type INTEGER NOT NULL DEFAULT 0;