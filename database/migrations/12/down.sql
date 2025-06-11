PRAGMA user_version = 11;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP COLUMN bid_price_limit_markup_non_justified_profile;
ALTER TABLE Configuration DROP COLUMN bid_price_limit_markup_justified_profile;
ALTER TABLE Configuration DROP COLUMN bid_price_limit_markup_non_justified_independent;
ALTER TABLE Configuration DROP COLUMN bid_price_limit_markup_justified_independent;
ALTER TABLE Configuration DROP COLUMN bid_price_limit_low_reference;
ALTER TABLE Configuration DROP COLUMN bid_price_limit_high_reference;
ALTER TABLE Configuration DROP COLUMN bidding_group_bid_validation;

ALTER TABLE BiddingGroup ADD COLUMN bid_type INTEGER NOT NULL DEFAULT 0;
