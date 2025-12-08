-- Rename Supply Function Equilibrium (SFE) parameters from reference_curve_nash_* to supply_function_equilibrium_*

-- Create new columns with updated names
ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_extra_bid_quantity REAL DEFAULT 0.0;
ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_tolerance REAL DEFAULT 0.0;
ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_max_iterations INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_max_cost_multiplier REAL DEFAULT 0.0;

-- Copy data from old columns to new columns
UPDATE Configuration SET supply_function_equilibrium_extra_bid_quantity = reference_curve_nash_extra_bid_quantity;
UPDATE Configuration SET supply_function_equilibrium_tolerance = reference_curve_nash_tolerance;
UPDATE Configuration SET supply_function_equilibrium_max_iterations = reference_curve_nash_max_iterations;
UPDATE Configuration SET supply_function_equilibrium_max_cost_multiplier = reference_curve_nash_max_cost_multiplier;

-- Drop old columns
ALTER TABLE Configuration DROP COLUMN reference_curve_nash_extra_bid_quantity;
ALTER TABLE Configuration DROP COLUMN reference_curve_nash_tolerance;
ALTER TABLE Configuration DROP COLUMN reference_curve_nash_max_iterations;
ALTER TABLE Configuration DROP COLUMN reference_curve_nash_max_cost_multiplier;
