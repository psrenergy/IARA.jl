PRAGMA user_version = 13;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN purchase_bids_for_virtual_reservoir_heuristic_bid INTEGER NOT NULL DEFAULT 1; 