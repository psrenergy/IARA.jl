PRAGMA user_version = 6;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration_vector_expected_number_of_repeats_per_node ADD COLUMN temp_expected_number_of_repeats_per_node INT;
UPDATE Configuration_vector_expected_number_of_repeats_per_node SET temp_expected_number_of_repeats_per_node = expected_number_of_repeats_per_node;
ALTER TABLE Configuration_vector_expected_number_of_repeats_per_node DROP COLUMN expected_number_of_repeats_per_node;
ALTER TABLE Configuration_vector_expected_number_of_repeats_per_node RENAME COLUMN temp_expected_number_of_repeats_per_node TO expected_number_of_repeats_per_node;

