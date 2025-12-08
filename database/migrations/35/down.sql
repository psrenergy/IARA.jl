-- Revert renaming of Supply Function Equilibrium (SFE) parameters from supply_function_equilibrium_* back to reference_curve_nash_*

-- Create old columns
ALTER TABLE Configuration ADD COLUMN reference_curve_nash_extra_bid_quantity REAL DEFAULT 0.0;
ALTER TABLE Configuration ADD COLUMN reference_curve_nash_tolerance REAL DEFAULT 0.0;
ALTER TABLE Configuration ADD COLUMN reference_curve_nash_max_iterations INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN reference_curve_nash_max_cost_multiplier REAL DEFAULT 0.0;

-- Copy data from new columns back to old columns
UPDATE Configuration SET reference_curve_nash_extra_bid_quantity = supply_function_equilibrium_extra_bid_quantity;
UPDATE Configuration SET reference_curve_nash_tolerance = supply_function_equilibrium_tolerance;
UPDATE Configuration SET reference_curve_nash_max_iterations = supply_function_equilibrium_max_iterations;
UPDATE Configuration SET reference_curve_nash_max_cost_multiplier = supply_function_equilibrium_max_cost_multiplier;

-- Drop new columns
ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_extra_bid_quantity;
ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_tolerance;
ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_max_iterations;
ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_max_cost_multiplier;
