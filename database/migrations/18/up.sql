PRAGMA user_version = 18;
PRAGMA foreign_keys = ON;

ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN quantity_offer TO quantity_bid;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN price_offer TO price_bid;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN quantity_offer_profile TO quantity_bid_profile;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN price_offer_profile TO price_bid_profile;
ALTER TABLE VirtualReservoir_time_series_files RENAME COLUMN quantity_offer TO quantity_bid;
ALTER TABLE VirtualReservoir_time_series_files RENAME COLUMN price_offer TO price_bid;
