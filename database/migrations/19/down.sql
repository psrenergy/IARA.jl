PRAGMA user_version = 18;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN price_limits INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration RENAME COLUMN bid_data_processing TO bid_data_source;
UPDATE Configuration SET bid_data_source = CASE
    WHEN bid_data_source = 0 THEN 0
    WHEN bid_data_source = 1 THEN 0
    WHEN bid_data_source = 2 THEN 1
    WHEN bid_data_source = 3 THEN 1
    ELSE 0
END;
ALTER TABLE Configuration ADD COLUMN bidding_group_bid_validation;
UPDATE Configuration SET bidding_group_bid_validation = CASE
    WHEN bid_data_source = 0 THEN 0
    WHEN bid_data_source = 1 THEN 1
    WHEN bid_data_source = 2 THEN 0
    WHEN bid_data_source = 3 THEN 1
    ELSE 0
END;
UPDATE Configuration SET make_whole_payments = 0;
