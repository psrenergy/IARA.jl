PRAGMA user_version = 38;

ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_extra_bid_quantity;
ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_tolerance;

ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_min_slope REAL NOT NULL DEFAULT 0.02;
ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_max_slope REAL NOT NULL DEFAULT 50.0;
