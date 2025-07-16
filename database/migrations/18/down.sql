PRAGMA user_version = 17;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN price_limits INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration RENAME COLUMN bid_data_processing TO bid_data_source;
UPDATE Configuration SET bid_data_source = 1 WHERE bid_data_source = 2;
UPDATE Configuration SET make_whole_payments = 0;
