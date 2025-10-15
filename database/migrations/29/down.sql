PRAGMA user_version = 28;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP COLUMN reference_curve_nash_extra_bid_quantity;
ALTER TABLE Configuration DROP COLUMN reference_curve_nash_tolerance;
ALTER TABLE Configuration DROP COLUMN reference_curve_nash_max_iterations;
ALTER TABLE Configuration DROP COLUMN reference_curve_nash_max_cost_multiplier;
