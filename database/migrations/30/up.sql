PRAGMA user_version = 30;
PRAGMA foreign_keys = ON;

-- Step 1: Add new columns to Configuration table
ALTER TABLE Configuration ADD COLUMN bid_price_validation INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN bid_processing INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN max_rev_equilibrium_bus_aggregation_type INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN max_rev_equilibrium_bid_initialization INTEGER NOT NULL DEFAULT 0;

-- Step 2: Migrate data from old columns to new columns
-- Map bid_data_processing to bid_processing and bid_price_validation
UPDATE Configuration SET bid_processing = CASE
    WHEN bid_data_processing IN (0, 1) THEN 0  -- EXTERNAL_*_BID -> READ_BIDS_FROM_FILE
    WHEN bid_data_processing IN (2, 3) THEN 1  -- HEURISTIC_*_BID -> PARAMETERIZED_HEURISTIC_BIDS
    ELSE 0
END;

UPDATE Configuration SET bid_price_validation = CASE
    WHEN bid_data_processing IN (0, 2) THEN 0  -- UNVALIDATED -> DO_NOT_VALIDATE
    WHEN bid_data_processing IN (1, 3) THEN 1  -- VALIDATED -> VALIDATE_WITH_DEFAULT_LIMIT
    ELSE 0
END;

-- Map clearing_hydro_representation to bid_processing
-- If clearing_hydro_representation indicates Nash equilibrium, set bid_processing accordingly
UPDATE Configuration SET bid_processing = CASE
    WHEN clearing_hydro_representation = 2 THEN 2  -- NASH_EQUILIBRIUM -> ITERATED_BIDS_FROM_SUPPLY_FUNCTION_EQUILIBRIUM
    WHEN clearing_hydro_representation = 1 AND bid_processing = 1 THEN 1  -- Keep HEURISTIC if already set
    WHEN clearing_hydro_representation = 1 AND bid_processing = 0 THEN 1  -- HEURISTIC -> PARAMETERIZED_HEURISTIC_BIDS
    ELSE bid_processing  -- Keep existing value from bid_data_processing migration
END;

-- Map nash_equilibrium_strategy to max_rev_equilibrium_bus_aggregation_type
UPDATE Configuration SET max_rev_equilibrium_bus_aggregation_type = CASE
    WHEN nash_equilibrium_strategy = 3 THEN 1  -- ITERATION_WITH_AGGREGATE_BUSES -> AGGREGATE_ALL_BUSES
    ELSE 0  -- All other values -> DO_NOT_AGGREGATE
END;

-- If nash_equilibrium_strategy is not 0, set bid_processing to MAX_REVENUE_ITERATED_BIDS
UPDATE Configuration SET bid_processing = 3  -- MAX_REVENUE_ITERATED_BIDS
WHERE nash_equilibrium_strategy != 0;

-- Map nash_equilibrium_initialization to max_rev_equilibrium_bid_initialization
UPDATE Configuration SET max_rev_equilibrium_bid_initialization = CASE
    WHEN nash_equilibrium_initialization = 0 THEN 1  -- MIN_COST_HEURISTIC -> PARAMETERIZED_HEURISTIC_BIDS
    WHEN nash_equilibrium_initialization = 1 THEN 0  -- EXTERNAL_BID -> READ_BIDS_FROM_FILE
    ELSE 0
END;

-- Step 3: Handle BiddingGroup.bid_price_limit_source migration
-- Update Configuration.bid_price_validation based on BiddingGroup.bid_price_limit_source
-- Note: This assumes if ANY bidding group uses READ_FROM_FILE, we should validate with file limits
-- Only set to VALIDATE_WITH_LIMIT_READ_FROM_FILE if bids were already being validated
UPDATE Configuration SET bid_price_validation = 2  -- VALIDATE_WITH_LIMIT_READ_FROM_FILE
WHERE bid_price_validation = 1  -- Only if already VALIDATE_WITH_DEFAULT_LIMIT
    AND (SELECT COUNT(*) FROM BiddingGroup WHERE bid_price_limit_source = 1) > 0;

-- Step 4: Drop old columns from Configuration table
ALTER TABLE Configuration DROP COLUMN bid_data_processing;
ALTER TABLE Configuration DROP COLUMN clearing_hydro_representation;
ALTER TABLE Configuration DROP COLUMN nash_equilibrium_strategy;
ALTER TABLE Configuration DROP COLUMN nash_equilibrium_initialization;

-- Step 5: Drop old column from BiddingGroup table
ALTER TABLE BiddingGroup DROP COLUMN bid_price_limit_source;
