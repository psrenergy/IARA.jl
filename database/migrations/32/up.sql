PRAGMA user_version = 32;

ALTER TABLE Configuration RENAME COLUMN market_clearing_tiebreaker_weight TO market_clearing_tiebreaker_weight_for_om_costs;
ALTER TABLE Configuration ADD COLUMN market_clearing_tiebreaker_weight_for_fcf REAL NOT NULL DEFAULT 0.0;
ALTER TABLE Configuration DROP COLUMN use_fcf_in_clearing;

DROP TABLE HydroUnit_vector_waveguide;
ALTER TABLE Configuration DROP COLUMN vr_curveguide_data_source;
ALTER TABLE Configuration DROP COLUMN vr_curveguide_data_format;
ALTER TABLE VirtualReservoir DROP COLUMN number_of_waveguide_points_for_file_template;