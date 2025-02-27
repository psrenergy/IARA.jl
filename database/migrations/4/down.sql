PRAGMA user_version = 3;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD number_of_bid_segments_for_file_template INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD number_of_bid_segments_for_virtual_reservoir_file_template INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD number_of_profiles_for_file_template INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD number_of_complementary_groups_for_file_template INTEGER DEFAULT 0;

ALTER TABLE Configuration DROP network_representation_mincost;
ALTER TABLE Configuration DROP network_representation_ex_ante_physical;
ALTER TABLE Configuration DROP network_representation_ex_ante_commercial;
ALTER TABLE Configuration DROP network_representation_ex_post_physical;
ALTER TABLE Configuration DROP network_representation_ex_post_commercial;

ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_mincost TO integer_variable_representation_mincost_type;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_ante_physical TO integer_variable_representation_ex_ante_physical_type;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_ante_commercial TO integer_variable_representation_ex_ante_commercial_type;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_post_physical TO integer_variable_representation_ex_post_physical_type;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_post_commercial TO integer_variable_representation_ex_post_commercial_type;

DROP TABLE Interconnection;
DROP TABLE Interconnection_time_series_parameters;