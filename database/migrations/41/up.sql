PRAGMA user_version = 41;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_force_origin_on_output INTEGER NOT NULL DEFAULT 1;
