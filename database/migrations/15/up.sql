PRAGMA user_version = 15;
PRAGMA foreign_keys = ON;

ALTER TABLE BiddingGroup ADD COLUMN bid_price_limit_source INTEGER NOT NULL DEFAULT 0; 
ALTER TABLE BiddingGroup_time_series_files ADD COLUMN bid_price_limit_justified_independent TEXT;
ALTER TABLE BiddingGroup_time_series_files ADD COLUMN bid_price_limit_non_justified_independent TEXT;
ALTER TABLE BiddingGroup_time_series_files ADD COLUMN bid_price_limit_justified_profile TEXT;
ALTER TABLE BiddingGroup_time_series_files ADD COLUMN bid_price_limit_non_justified_profile TEXT;
ALTER TABLE BiddingGroup_time_series_files ADD COLUMN bid_justifications TEXT;
