PRAGMA user_version = 10;
PRAGMA foreign_keys = ON;

CREATE TABLE Configuration_vector_reference_curve_demand_multipliers (
    id INTEGER, 
    vector_index INTEGER NOT NULL,
    reference_curve_demand_multipliers INTEGER,
    FOREIGN KEY(id) REFERENCES Configuration(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;
