PRAGMA user_version = 32;

ALTER TABLE Configuration RENAME COLUMN virtual_reservoir_residual_revenue_split_type TO old_virtual_reservoir_residual_revenue_split_type;
ALTER TABLE Configuration ADD COLUMN virtual_reservoir_residual_revenue_split_type INTEGER NOT NULL DEFAULT 0;

UPDATE Configuration
SET virtual_reservoir_residual_revenue_split_type = (SELECT old_virtual_reservoir_residual_revenue_split_type FROM Configuration LIMIT 1);

ALTER TABLE Configuration DROP COLUMN old_virtual_reservoir_residual_revenue_split_type;

ALTER TABLE Configuration ADD COLUMN purchase_bids_for_virtual_reservoir_heuristic_bid INTEGER NOT NULL DEFAULT 1; 

ALTER TABLE Configuration ADD COLUMN virtual_reservoir_initial_energy_account_share INTEGER NOT NULL DEFAULT 0;