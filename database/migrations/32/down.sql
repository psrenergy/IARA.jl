PRAGMA user_version = 31;

ALTER TABLE Configuration RENAME COLUMN market_clearing_tiebreaker_weight_for_om_costs TO market_clearing_tiebreaker_weight;
ALTER TABLE Configuration DROP COLUMN market_clearing_tiebreaker_weight_for_fcf;
ALTER TABLE Configuration ADD COLUMN use_fcf_in_clearing INTEGER NOT NULL DEFAULT 0;