PRAGMA user_version = 41;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN hydro_balance_subperiod_resolution INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN thermal_unit_intra_period_operation INTEGER;

UPDATE Configuration SET
    hydro_balance_subperiod_resolution = CASE WHEN intra_period_chronological_constraints = 2 THEN 1 ELSE 0 END,
    thermal_unit_intra_period_operation = CASE WHEN intra_period_chronological_constraints = 1 THEN 1 ELSE 0 END;

ALTER TABLE Configuration DROP COLUMN intra_period_chronological_constraints;
