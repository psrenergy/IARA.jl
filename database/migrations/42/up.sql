PRAGMA user_version = 42;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN intra_period_chronological_constraints INTEGER NOT NULL DEFAULT 1;

UPDATE Configuration SET intra_period_chronological_constraints =
    CASE
        WHEN hydro_balance_subperiod_resolution = 1 THEN 2
        WHEN thermal_unit_intra_period_operation = 1 THEN 1
        ELSE 0
    END;

ALTER TABLE Configuration DROP COLUMN hydro_balance_subperiod_resolution;
ALTER TABLE Configuration DROP COLUMN thermal_unit_intra_period_operation;
