PRAGMA user_version = 32;

ALTER TABLE Configuration RENAME COLUMN market_clearing_tiebreaker_weight TO market_clearing_tiebreaker_weight_for_om_costs;
ALTER TABLE Configuration ADD COLUMN market_clearing_tiebreaker_weight_for_fcf REAL NOT NULL DEFAULT 0.0;
ALTER TABLE Configuration DROP COLUMN use_fcf_in_clearing;