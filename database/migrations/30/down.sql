PRAGMA user_version = 29;
PRAGMA foreign_keys = ON;

-- Step 1: Add back old columns to Configuration table
ALTER TABLE Configuration ADD COLUMN bid_data_processing INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_hydro_representation INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN nash_equilibrium_strategy INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN nash_equilibrium_initialization INTEGER NOT NULL DEFAULT 0;

-- Step 2: Add back old column to BiddingGroup table
ALTER TABLE BiddingGroup ADD COLUMN bid_price_limit_source INTEGER NOT NULL DEFAULT 0;

-- Step 3: Migrate data from new columns back to old columns
-- Reconstruct bid_data_processing from bid_processing and bid_price_validation
UPDATE Configuration SET bid_data_processing = CASE
    -- bid_processing = 0 (READ_BIDS_FROM_FILE)
    WHEN bid_processing = 0 AND bid_price_validation = 0 THEN 0  -- EXTERNAL_UNVALIDATED_BID
    WHEN bid_processing = 0 AND bid_price_validation IN (1, 2) THEN 1  -- EXTERNAL_VALIDATED_BID
    -- bid_processing = 1 (PARAMETERIZED_HEURISTIC_BIDS)
    WHEN bid_processing = 1 AND bid_price_validation = 0 THEN 2  -- HEURISTIC_UNVALIDATED_BID
    WHEN bid_processing = 1 AND bid_price_validation IN (1, 2) THEN 3  -- HEURISTIC_VALIDATED_BID
    -- bid_processing = 2 (ITERATED_BIDS_FROM_SUPPLY_FUNCTION_EQUILIBRIUM)
    -- bid_processing = 3 (MAX_REVENUE_ITERATED_BIDS)
    -- For cases 2 and 3, or any other unexpected value, use default fallback
    ELSE 0  -- EXTERNAL_UNVALIDATED_BID as fallback
END;

-- Reconstruct clearing_hydro_representation from bid_processing
UPDATE Configuration SET clearing_hydro_representation = CASE
    WHEN bid_processing = 2 THEN 2  -- ITERATED_BIDS_FROM_SUPPLY_FUNCTION_EQUILIBRIUM -> NASH_EQUILIBRIUM_FROM_HYDRO_REFERENCE_CURVE
    WHEN bid_processing IN (1, 3) THEN 1  -- PARAMETERIZED_HEURISTIC_BIDS or MAX_REVENUE_ITERATED_BIDS -> HEURISTIC_BID_FROM_HYDRO_REFERENCE_CURVE
    ELSE 0  -- READ_BIDS_FROM_FILE -> IGNORE_VIRTUAL_RESERVOIRS
END;

-- Reconstruct nash_equilibrium_strategy from max_rev_equilibrium_bus_aggregation_type and bid_processing
UPDATE Configuration SET nash_equilibrium_strategy = CASE
    WHEN bid_processing = 3 AND max_rev_equilibrium_bus_aggregation_type = 1 THEN 3  -- ITERATION_WITH_AGGREGATE_BUSES
    WHEN bid_processing = 3 THEN 1  -- Default to ITERATION (nash strategy was active)
    ELSE 0  -- NO_ITERATION
END;

-- Reconstruct nash_equilibrium_initialization from max_rev_equilibrium_bid_initialization
UPDATE Configuration SET nash_equilibrium_initialization = CASE
    WHEN max_rev_equilibrium_bid_initialization = 1 THEN 0  -- PARAMETERIZED_HEURISTIC_BIDS -> MIN_COST_HEURISTIC
    WHEN max_rev_equilibrium_bid_initialization = 0 THEN 1  -- READ_BIDS_FROM_FILE -> EXTERNAL_BID
    ELSE 0
END;

-- Reconstruct BiddingGroup.bid_price_limit_source from Configuration.bid_price_validation
-- If bid_price_validation is 2 (VALIDATE_WITH_LIMIT_READ_FROM_FILE), set all bidding groups to READ_FROM_FILE
UPDATE BiddingGroup SET bid_price_limit_source = 1  -- READ_FROM_FILE
WHERE (SELECT bid_price_validation FROM Configuration) = 2;

-- Step 4: Drop new columns from Configuration table
ALTER TABLE Configuration DROP COLUMN bid_price_validation;
ALTER TABLE Configuration DROP COLUMN bid_processing;
ALTER TABLE Configuration DROP COLUMN max_rev_equilibrium_bus_aggregation_type;
ALTER TABLE Configuration DROP COLUMN max_rev_equilibrium_bid_initialization;
