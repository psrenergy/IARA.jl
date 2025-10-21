PRAGMA user_version = 31;
PRAGMA foreign_keys = ON;

-- Step 1: Add new inflow_model column to Configuration table
ALTER TABLE Configuration ADD COLUMN inflow_model INTEGER NOT NULL DEFAULT 0;

-- Step 2: Migrate data from inflow_scenarios_files to inflow_model
-- Map the old PAR(p) values to the new inflow_model enum:
-- Old FIT_PARP_MODEL_FROM_DATA (0) -> New FIT_PARP_MODEL_FROM_DATA (1)
-- Old READ_PARP_COEFFICIENTS (4) -> New READ_PARP_COEFFICIENTS (2)
-- All other values (file-based: 1, 2, 3) -> READ_INFLOW_FROM_FILE (0)

UPDATE Configuration SET inflow_model = CASE
    WHEN inflow_scenarios_files = 0 THEN 1  -- FIT_PARP_MODEL_FROM_DATA -> FIT_PARP_MODEL_FROM_DATA
    WHEN inflow_scenarios_files = 4 THEN 2  -- READ_PARP_COEFFICIENTS -> READ_PARP_COEFFICIENTS
    ELSE 0  -- All file-based options (1, 2, 3) -> READ_INFLOW_FROM_FILE
END;

-- Step 3: Update inflow_scenarios_files to remove PAR(p) values
-- For PAR(p) cases, use ONLY_EX_ANTE (0) as fallback since they don't use file-based scenarios
-- For file-based cases, remap to new enum values:
-- Old ONLY_EX_ANTE (1) -> New ONLY_EX_ANTE (0)
-- Old ONLY_EX_POST (2) -> New ONLY_EX_POST (1)
-- Old EX_ANTE_AND_EX_POST (3) -> New EX_ANTE_AND_EX_POST (2)

UPDATE Configuration SET inflow_scenarios_files = CASE
    WHEN inflow_scenarios_files = 0 THEN 0  -- FIT_PARP_MODEL_FROM_DATA -> ONLY_EX_ANTE (fallback)
    WHEN inflow_scenarios_files = 1 THEN 0  -- ONLY_EX_ANTE -> ONLY_EX_ANTE
    WHEN inflow_scenarios_files = 2 THEN 1  -- ONLY_EX_POST -> ONLY_EX_POST
    WHEN inflow_scenarios_files = 3 THEN 2  -- EX_ANTE_AND_EX_POST -> EX_ANTE_AND_EX_POST
    WHEN inflow_scenarios_files = 4 THEN 0  -- READ_PARP_COEFFICIENTS -> ONLY_EX_ANTE (fallback)
    ELSE 2  -- Default to EX_ANTE_AND_EX_POST for any unexpected values
END;

-- Step 3a: Update demand_scenarios_files to remap enum values
-- Old ONLY_EX_ANTE (1) -> New ONLY_EX_ANTE (0)
-- Old ONLY_EX_POST (2) -> New ONLY_EX_POST (1)
-- Old EX_ANTE_AND_EX_POST (3) -> New EX_ANTE_AND_EX_POST (2)

UPDATE Configuration SET demand_scenarios_files = CASE
    WHEN demand_scenarios_files = 1 THEN 0  -- ONLY_EX_ANTE -> ONLY_EX_ANTE
    WHEN demand_scenarios_files = 2 THEN 1  -- ONLY_EX_POST -> ONLY_EX_POST
    WHEN demand_scenarios_files = 3 THEN 2  -- EX_ANTE_AND_EX_POST -> EX_ANTE_AND_EX_POST
    ELSE 2  -- Default to EX_ANTE_AND_EX_POST for any unexpected values
END;

-- Step 3b: Update renewable_scenarios_files to remap enum values
-- Old ONLY_EX_ANTE (1) -> New ONLY_EX_ANTE (0)
-- Old ONLY_EX_POST (2) -> New ONLY_EX_POST (1)
-- Old EX_ANTE_AND_EX_POST (3) -> New EX_ANTE_AND_EX_POST (2)

UPDATE Configuration SET renewable_scenarios_files = CASE
    WHEN renewable_scenarios_files = 1 THEN 0  -- ONLY_EX_ANTE -> ONLY_EX_ANTE
    WHEN renewable_scenarios_files = 2 THEN 1  -- ONLY_EX_POST -> ONLY_EX_POST
    WHEN renewable_scenarios_files = 3 THEN 2  -- EX_ANTE_AND_EX_POST -> EX_ANTE_AND_EX_POST
    ELSE 2  -- Default to EX_ANTE_AND_EX_POST for any unexpected values
END;

-- Step 3c: Update default values for inflow_scenarios_files, demand_scenarios_files, and renewable_scenarios_files
-- Rename old columns, add new ones with correct DEFAULT 2, copy data, and drop old columns

-- For inflow_scenarios_files
ALTER TABLE Configuration RENAME COLUMN inflow_scenarios_files TO inflow_scenarios_files_old;
ALTER TABLE Configuration ADD COLUMN inflow_scenarios_files INTEGER NOT NULL DEFAULT 2;
UPDATE Configuration SET inflow_scenarios_files = inflow_scenarios_files_old;
ALTER TABLE Configuration DROP COLUMN inflow_scenarios_files_old;

-- For demand_scenarios_files
ALTER TABLE Configuration RENAME COLUMN demand_scenarios_files TO demand_scenarios_files_old;
ALTER TABLE Configuration ADD COLUMN demand_scenarios_files INTEGER NOT NULL DEFAULT 2;
UPDATE Configuration SET demand_scenarios_files = demand_scenarios_files_old;
ALTER TABLE Configuration DROP COLUMN demand_scenarios_files_old;

-- For renewable_scenarios_files
ALTER TABLE Configuration RENAME COLUMN renewable_scenarios_files TO renewable_scenarios_files_old;
ALTER TABLE Configuration ADD COLUMN renewable_scenarios_files INTEGER NOT NULL DEFAULT 2;
UPDATE Configuration SET renewable_scenarios_files = renewable_scenarios_files_old;
ALTER TABLE Configuration DROP COLUMN renewable_scenarios_files_old;

-- Step 4: Split inflow_noise into inflow_noise_ex_ante and inflow_noise_ex_post in GaugingStation_time_series_files
-- Add new columns
ALTER TABLE GaugingStation_time_series_files ADD COLUMN inflow_noise_ex_ante TEXT;
ALTER TABLE GaugingStation_time_series_files ADD COLUMN inflow_noise_ex_post TEXT;

-- Copy existing inflow_noise to inflow_noise_ex_ante
UPDATE GaugingStation_time_series_files SET inflow_noise_ex_ante = inflow_noise;

-- Drop the old inflow_noise column
ALTER TABLE GaugingStation_time_series_files DROP COLUMN inflow_noise;
