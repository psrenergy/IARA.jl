PRAGMA user_version = 37;

ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_min_slope;
ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_max_slope;

ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_extra_bid_quantity REAL DEFAULT 1.0;
ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_tolerance REAL DEFAULT 0.000001;
