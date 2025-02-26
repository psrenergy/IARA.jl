PRAGMA user_version = 4;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP number_of_bid_segments_for_file_template;
ALTER TABLE Configuration DROP number_of_bid_segments_for_virtual_reservoir_file_template;
ALTER TABLE Configuration DROP number_of_profiles_for_file_template;
ALTER TABLE Configuration DROP number_of_complementary_groups_for_file_template;