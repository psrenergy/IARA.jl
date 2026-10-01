PRAGMA user_version = 39;
PRAGMA foreign_keys = ON;

CREATE TABLE Configuration_vector_reference_curve_multipliers (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    reference_curve_multipliers REAL,
    FOREIGN KEY(id) REFERENCES Configuration(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;
