PRAGMA user_version = 24;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN hydro_minimum_outflow_violation_cost REAL;
ALTER TABLE Configuration ADD COLUMN hydro_spillage_cost REAL NOT NULL DEFAULT 0;

UPDATE Configuration
SET hydro_minimum_outflow_violation_cost = (SELECT minimum_outflow_violation_cost FROM HydroUnit LIMIT 1),
    hydro_spillage_cost = (SELECT spillage_cost FROM HydroUnit LIMIT 1);

ALTER TABLE HydroUnit DROP COLUMN minimum_outflow_violation_cost;
ALTER TABLE HydroUnit DROP COLUMN spillage_cost;