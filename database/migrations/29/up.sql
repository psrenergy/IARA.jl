PRAGMA user_version = 29;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN reference_curve_nash_extra_bid_quantity REAL DEFAULT 1.0;
ALTER TABLE Configuration ADD COLUMN reference_curve_nash_tolerance REAL DEFAULT 0.000001;
ALTER TABLE Configuration ADD COLUMN reference_curve_nash_max_iterations INTEGER DEFAULT 20;
ALTER TABLE Configuration ADD COLUMN reference_curve_nash_max_cost_multiplier REAL DEFAULT 2.0;
