PRAGMA user_version = 12;
PRAGMA foreign_keys = ON;

CREATE TABLE Configuration_vector_reference_curve_demand_multipliers (
    id INTEGER, 
    vector_index INTEGER NOT NULL,
    reference_curve_demand_multipliers REAL,
    FOREIGN KEY(id) REFERENCES Configuration(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

ALTER TABLE Configuration DROP COLUMN reference_curve_number_of_segments;
ALTER TABLE Configuration DROP COLUMN reference_curve_final_segment_price_markup;
