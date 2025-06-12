PRAGMA user_version = 13;
PRAGMA foreign_keys = ON;

DROP TABLE Configuration_vector_reference_curve_demand_multipliers;

ALTER TABLE Configuration ADD COLUMN reference_curve_number_of_segments INTEGER NOT NULL DEFAULT 10;
ALTER TABLE Configuration ADD COLUMN reference_curve_final_segment_price_markup REAL NOT NULL DEFAULT 0.01;