PRAGMA user_version = 25;
PRAGMA foreign_keys = ON;

ALTER TABLE HydroUnit ADD COLUMN minimum_outflow_violation_cost REAL;
ALTER TABLE HydroUnit ADD COLUMN spillage_cost REAL NOT NULL DEFAULT 0;

UPDATE HydroUnit 
SET minimum_outflow_violation_cost = (SELECT hydro_minimum_outflow_violation_cost FROM Configuration LIMIT 1),
    spillage_cost = (SELECT hydro_spillage_cost FROM Configuration LIMIT 1);

ALTER TABLE Configuration DROP COLUMN hydro_minimum_outflow_violation_cost;
ALTER TABLE Configuration DROP COLUMN hydro_spillage_cost;
