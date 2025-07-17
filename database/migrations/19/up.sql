PRAGMA user_version = 19;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP COLUMN price_limits;
ALTER TABLE Configuration RENAME COLUMN bid_data_source TO bid_data_processing;
UPDATE Configuration SET bid_data_processing = CASE
    WHEN bid_data_processing = 0 AND bidding_group_bid_validation = 0 THEN 0
    WHEN bid_data_processing = 0 AND bidding_group_bid_validation = 1 THEN 1
    WHEN bid_data_processing = 1 AND bidding_group_bid_validation = 0 THEN 2
    WHEN bid_data_processing = 1 AND bidding_group_bid_validation = 1 THEN 3
    ELSE 0
END;
ALTER TABLE Configuration DROP COLUMN bidding_group_bid_validation;
UPDATE Configuration SET make_whole_payments = 0;
