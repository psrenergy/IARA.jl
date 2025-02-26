PRAGMA user_version = 3;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD number_of_bid_segments_for_file_template INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD number_of_bid_segments_for_virtual_reservoir_file_template INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD number_of_profiles_for_file_template INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD number_of_complementary_groups_for_file_template INTEGER DEFAULT 0;