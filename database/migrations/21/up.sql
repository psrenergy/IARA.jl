PRAGMA user_version = 21;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration RENAME COLUMN loop_subperiods_for_thermal_constraints TO thermal_unit_intra_period_operation;
ALTER TABLE HydroUnit RENAME COLUMN operation_type TO intra_period_operation;
