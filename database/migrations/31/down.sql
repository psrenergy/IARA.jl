PRAGMA user_version = 30;
PRAGMA foreign_keys = ON;

-- Step 1: Merge inflow_noise_ex_ante and inflow_noise_ex_post back into inflow_noise
-- Add back the old inflow_noise column
ALTER TABLE GaugingStation_time_series_files ADD COLUMN inflow_noise TEXT;

-- Use inflow_noise_ex_ante as the default
UPDATE GaugingStation_time_series_files SET inflow_noise = inflow_noise_ex_ante;

-- Drop the new columns
ALTER TABLE GaugingStation_time_series_files DROP COLUMN inflow_noise_ex_ante;
ALTER TABLE GaugingStation_time_series_files DROP COLUMN inflow_noise_ex_post;

-- Step 1a: Restore default values to 3 for the three scenario file columns
-- Rename current columns, add new ones with old DEFAULT 3, copy data, and drop renamed columns

-- For inflow_scenarios_files
ALTER TABLE Configuration RENAME COLUMN inflow_scenarios_files TO inflow_scenarios_files_new;
ALTER TABLE Configuration ADD COLUMN inflow_scenarios_files INTEGER NOT NULL DEFAULT 3;
UPDATE Configuration SET inflow_scenarios_files = inflow_scenarios_files_new;
ALTER TABLE Configuration DROP COLUMN inflow_scenarios_files_new;

-- For demand_scenarios_files
ALTER TABLE Configuration RENAME COLUMN demand_scenarios_files TO demand_scenarios_files_new;
ALTER TABLE Configuration ADD COLUMN demand_scenarios_files INTEGER NOT NULL DEFAULT 3;
UPDATE Configuration SET demand_scenarios_files = demand_scenarios_files_new;
ALTER TABLE Configuration DROP COLUMN demand_scenarios_files_new;

-- For renewable_scenarios_files
ALTER TABLE Configuration RENAME COLUMN renewable_scenarios_files TO renewable_scenarios_files_new;
ALTER TABLE Configuration ADD COLUMN renewable_scenarios_files INTEGER NOT NULL DEFAULT 3;
UPDATE Configuration SET renewable_scenarios_files = renewable_scenarios_files_new;
ALTER TABLE Configuration DROP COLUMN renewable_scenarios_files_new;

-- Step 2: Restore inflow_scenarios_files to include PAR(p) values
-- Reverse the mapping:
-- If inflow_model = 1 (FIT_PARP_MODEL_FROM_DATA) -> inflow_scenarios_files = 0
-- If inflow_model = 2 (READ_PARP_COEFFICIENTS) -> inflow_scenarios_files = 4
-- Otherwise remap file-based values:
-- New ONLY_EX_ANTE (0) -> Old ONLY_EX_ANTE (1)
-- New ONLY_EX_POST (1) -> Old ONLY_EX_POST (2)
-- New EX_ANTE_AND_EX_POST (2) -> Old EX_ANTE_AND_EX_POST (3)

UPDATE Configuration SET inflow_scenarios_files = CASE
    WHEN inflow_model = 1 THEN 0  -- FIT_PARP_MODEL_FROM_DATA
    WHEN inflow_model = 2 THEN 4  -- READ_PARP_COEFFICIENTS
    WHEN inflow_scenarios_files = 0 THEN 1  -- ONLY_EX_ANTE
    WHEN inflow_scenarios_files = 1 THEN 2  -- ONLY_EX_POST
    WHEN inflow_scenarios_files = 2 THEN 3  -- EX_ANTE_AND_EX_POST
    ELSE 3  -- Default to old EX_ANTE_AND_EX_POST
END;

-- Step 2a: Restore demand_scenarios_files to old enum values
-- New ONLY_EX_ANTE (0) -> Old ONLY_EX_ANTE (1)
-- New ONLY_EX_POST (1) -> Old ONLY_EX_POST (2)
-- New EX_ANTE_AND_EX_POST (2) -> Old EX_ANTE_AND_EX_POST (3)

UPDATE Configuration SET demand_scenarios_files = CASE
    WHEN demand_scenarios_files = 0 THEN 1  -- ONLY_EX_ANTE
    WHEN demand_scenarios_files = 1 THEN 2  -- ONLY_EX_POST
    WHEN demand_scenarios_files = 2 THEN 3  -- EX_ANTE_AND_EX_POST
    ELSE 3  -- Default to old EX_ANTE_AND_EX_POST
END;

-- Step 2b: Restore renewable_scenarios_files to old enum values
-- New ONLY_EX_ANTE (0) -> Old ONLY_EX_ANTE (1)
-- New ONLY_EX_POST (1) -> Old ONLY_EX_POST (2)
-- New EX_ANTE_AND_EX_POST (2) -> Old EX_ANTE_AND_EX_POST (3)

UPDATE Configuration SET renewable_scenarios_files = CASE
    WHEN renewable_scenarios_files = 0 THEN 1  -- ONLY_EX_ANTE
    WHEN renewable_scenarios_files = 1 THEN 2  -- ONLY_EX_POST
    WHEN renewable_scenarios_files = 2 THEN 3  -- EX_ANTE_AND_EX_POST
    ELSE 3  -- Default to old EX_ANTE_AND_EX_POST
END;

-- Step 3: Drop the inflow_model column
ALTER TABLE Configuration DROP COLUMN inflow_model;
