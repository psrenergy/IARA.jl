PRAGMA user_version = 31;

ALTER TABLE Configuration RENAME COLUMN market_clearing_tiebreaker_weight_for_om_costs TO market_clearing_tiebreaker_weight;
ALTER TABLE Configuration DROP COLUMN market_clearing_tiebreaker_weight_for_fcf;
ALTER TABLE Configuration ADD COLUMN use_fcf_in_clearing INTEGER NOT NULL DEFAULT 0;

CREATE TABLE HydroUnit_vector_waveguide (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    waveguide_volume REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES HydroUnit(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

ALTER TABLE Configuration ADD COLUMN vr_curveguide_data_source INTEGER DEFAULT 1;
ALTER TABLE Configuration ADD COLUMN vr_curveguide_data_format INTEGER DEFAULT 0;
ALTER TABLE VirtualReservoir ADD COLUMN number_of_waveguide_points_for_file_template INTEGER;