PRAGMA user_version = 3;
PRAGMA foreign_keys = ON;

ALTER TABLE Bus ADD COLUMN latitude REAL;
ALTER TABLE Bus ADD COLUMN longitude REAL;

ALTER TABLE BiddingGroup DROP COLUMN independent_bid_max_segments;
ALTER TABLE BiddingGroup DROP COLUMN profile_bid_max_profiles;
ALTER TABLE DemandUnit ADD COLUMN max_demand REAL NOT NULL;

ALTER TABLE Configuration ADD COLUMN renewable_scenarios_files INTEGER NOT NULL DEFAULT 3;
ALTER TABLE Configuration ADD COLUMN inflow_scenarios_files INTEGER NOT NULL DEFAULT 3;
ALTER TABLE Configuration ADD COLUMN demand_scenarios_files INTEGER NOT NULL DEFAULT 3;
ALTER TABLE Configuration ADD COLUMN market_clearing_tiebreaker_weight REAL NOT NULL DEFAULT 0.001;

UPDATE Configuration SET inflow_scenarios_files = 0 WHERE inflow_source = 0;
ALTER TABLE Configuration DROP COLUMN inflow_source;

ALTER TABLE RenewableUnit_time_series_files ADD COLUMN generation_ex_ante TEXT;
UPDATE RenewableUnit_time_series_files SET generation_ex_ante = generation;
ALTER TABLE RenewableUnit_time_series_files DROP COLUMN generation;
ALTER TABLE RenewableUnit_time_series_files ADD COLUMN generation_ex_post TEXT;

ALTER TABLE HydroUnit_time_series_files ADD COLUMN inflow_ex_ante TEXT;
UPDATE HydroUnit_time_series_files SET inflow_ex_ante = inflow;
ALTER TABLE HydroUnit_time_series_files DROP COLUMN inflow;
ALTER TABLE HydroUnit_time_series_files ADD COLUMN inflow_ex_post TEXT;

ALTER TABLE DemandUnit_time_series_files ADD COLUMN demand_ex_ante TEXT;
UPDATE DemandUnit_time_series_files SET demand_ex_ante = demand;
ALTER TABLE DemandUnit_time_series_files DROP COLUMN demand;
ALTER TABLE DemandUnit_time_series_files ADD COLUMN demand_ex_post TEXT;

ALTER TABLE Configuration DROP COLUMN clearing_network_representation;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_ante_commercial_source;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_post_physical_source;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_post_commercial_source;

ALTER TABLE Configuration ADD COLUMN integer_variable_representation_mincost_type INTEGER DEFAULT 0;
UPDATE Configuration SET integer_variable_representation_mincost_type = 2 WHERE use_binary_variables = 0;
UPDATE Configuration SET integer_variable_representation_mincost_type = 0 WHERE use_binary_variables = 1;
ALTER TABLE Configuration DROP COLUMN use_binary_variables;
ALTER TABLE Configuration DROP COLUMN number_of_virtual_reservoir_bidding_segments;

-- Renaming

ALTER TABLE Configuration RENAME COLUMN price_cap TO price_limits;
ALTER TABLE Configuration RENAME COLUMN reservoirs_physical_virtual_correspondence_type TO virtual_reservoir_correspondence_type;
ALTER TABLE Configuration RENAME COLUMN clearing_bid_source TO bid_data_source;
ALTER TABLE Configuration RENAME COLUMN period_type TO time_series_step;
ALTER TABLE Configuration RENAME COLUMN clearing_model_type_ex_ante_physical TO construction_type_ex_ante_physical;
ALTER TABLE Configuration RENAME COLUMN clearing_model_type_ex_ante_commercial TO construction_type_ex_ante_commercial;
ALTER TABLE Configuration RENAME COLUMN clearing_model_type_ex_post_physical TO construction_type_ex_post_physical;
ALTER TABLE Configuration RENAME COLUMN clearing_model_type_ex_post_commercial TO construction_type_ex_post_commercial;
ALTER TABLE Configuration RENAME COLUMN virtual_reservoir_waveguide_source TO vr_curveguide_data_source;
ALTER TABLE Configuration RENAME COLUMN waveguide_user_provided_source TO vr_curveguide_data_format;
ALTER TABLE Configuration RENAME COLUMN clearing_integer_variables_ex_ante_physical_type TO integer_variable_representation_ex_ante_physical_type;
ALTER TABLE Configuration RENAME COLUMN clearing_integer_variables_ex_ante_commercial_type TO integer_variable_representation_ex_ante_commercial_type;
ALTER TABLE Configuration RENAME COLUMN clearing_integer_variables_ex_post_physical_type TO integer_variable_representation_ex_post_physical_type;
ALTER TABLE Configuration RENAME COLUMN clearing_integer_variables_ex_post_commercial_type TO integer_variable_representation_ex_post_commercial_type;
