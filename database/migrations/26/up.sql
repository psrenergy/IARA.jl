PRAGMA user_version = 26;
PRAGMA foreign_keys = ON;

ALTER TABLE HydroUnit ADD COLUMN minimum_outflow_violation_benchmark REAL NOT NULL DEFAULT 0.0;
