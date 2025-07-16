PRAGMA user_version = 18;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP COLUMN price_limits;
ALTER TABLE Configuration RENAME COLUMN bid_data_source TO bid_data_processing;
UPDATE Configuration SET bid_data_processing = 2 WHERE bid_data_processing = 1;
UPDATE Configuration SET make_whole_payments = 0;
