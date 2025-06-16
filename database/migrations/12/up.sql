PRAGMA user_version = 12;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN bid_price_limit_markup_non_justified_profile REAL NOT NULL DEFAULT 0.1;
ALTER TABLE Configuration ADD COLUMN bid_price_limit_markup_justified_profile REAL NOT NULL DEFAULT 0.2;
ALTER TABLE Configuration ADD COLUMN bid_price_limit_markup_non_justified_independent REAL NOT NULL DEFAULT 0.5;
ALTER TABLE Configuration ADD COLUMN bid_price_limit_markup_justified_independent REAL NOT NULL DEFAULT 1.0;
ALTER TABLE Configuration ADD COLUMN bid_price_limit_low_reference REAL;
ALTER TABLE Configuration ADD COLUMN bid_price_limit_high_reference REAL NOT NULL DEFAULT 1000000.0;
ALTER TABLE Configuration ADD COLUMN bidding_group_bid_validation INTEGER NOT NULL DEFAULT 0;

ALTER TABLE BiddingGroup DROP COLUMN bid_type;
