PRAGMA user_version = 17;
PRAGMA foreign_keys = ON;

ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN quantity_bid TO quantity_offer;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN price_bid TO price_offer;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN quantity_bid_profile TO quantity_offer_profile;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN price_bid_profile TO price_offer_profile;
ALTER TABLE VirtualReservoir_time_series_files RENAME COLUMN quantity_bid TO quantity_offer;
ALTER TABLE VirtualReservoir_time_series_files RENAME COLUMN price_bid TO price_offer;
