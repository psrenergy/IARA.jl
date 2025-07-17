PRAGMA user_version = 18;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration RENAME COLUMN thermal_unit_intra_period_operation TO loop_subperiods_for_thermal_constraints;
ALTER TABLE HydroUnit RENAME COLUMN intra_period_operation TO operation_type;