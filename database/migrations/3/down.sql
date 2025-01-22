PRAGMA user_version = 2;

ALTER TABLE Bus DROP COLUMN latitude;
ALTER TABLE Bus DROP COLUMN longitude;

ALTER TABLE BiddingGroup ADD COLUMN independent_bid_max_segments INTEGER DEFAULT 0;
ALTER TABLE BiddingGroup ADD COLUMN profile_bid_max_profiles INTEGER DEFAULT 0;
ALTER TABLE DemandUnit DROP COLUMN max_demand;

ALTER TABLE Configuration DROP COLUMN renewable_scenarios_files;
ALTER TABLE Configuration DROP COLUMN inflow_scenarios_files;
ALTER TABLE Configuration DROP COLUMN demand_scenarios_files;
ALTER TABLE Configuration DROP COLUMN market_clearing_tiebreaker_weight;

ALTER TABLE Configuration ADD COLUMN inflow_source INTEGER NOT NULL DEFAULT 1;

ALTER TABLE RenewableUnit_time_series_files ADD COLUMN generation TEXT NOT NULL;
UPDATE RenewableUnit_time_series_files SET generation = generation_ex_ante WHERE generation_ex_ante IS NOT NULL;
ALTER TABLE RenewableUnit_time_series_files DROP COLUMN generation_ex_ante;
ALTER TABLE RenewableUnit_time_series_files DROP COLUMN generation_ex_post;

ALTER TABLE HydroUnit_time_series_files ADD COLUMN inflow TEXT NOT NULL;
UPDATE HydroUnit_time_series_files SET inflow = inflow_ex_ante WHERE inflow_ex_ante IS NOT NULL;
ALTER TABLE HydroUnit_time_series_files DROP COLUMN inflow_ex_ante;
ALTER TABLE HydroUnit_time_series_files DROP COLUMN inflow_ex_post;

ALTER TABLE DemandUnit_time_series_files ADD COLUMN demand TEXT NOT NULL;
UPDATE DemandUnit_time_series_files SET demand = demand_ex_ante WHERE demand_ex_ante IS NOT NULL;
ALTER TABLE DemandUnit_time_series_files DROP COLUMN demand_ex_ante;
ALTER TABLE DemandUnit_time_series_files DROP COLUMN demand_ex_post;

ALTER TABLE Configuration ADD COLUMN clearing_network_representation INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_ante_commercial_source INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_post_physical_source INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_post_commercial_source INTEGER DEFAULT 0;

ALTER TABLE Configuration ADD COLUMN use_binary_variables INTEGER NOT NULL DEFAULT 0;
UPDATE Configuration SET use_binary_variables = 0 WHERE integer_variable_representation_mincost_type = 2;
UPDATE Configuration SET use_binary_variables = 1 WHERE integer_variable_representation_mincost_type = 0;
ALTER TABLE Configuration DROP COLUMN integer_variable_representation_mincost_type;
ALTER TABLE Configuration ADD COLUMN number_of_virtual_reservoir_bidding_segments INTEGER DEFAULT 0;

-- Renaming

ALTER TABLE Configuration RENAME COLUMN price_limits TO price_cap;
ALTER TABLE Configuration RENAME COLUMN virtual_reservoir_correspondence_type TO reservoirs_physical_virtual_correspondence_type;
ALTER TABLE Configuration RENAME COLUMN bid_data_source TO clearing_bid_source;
ALTER TABLE Configuration RENAME COLUMN time_series_step TO period_type;
ALTER TABLE Configuration RENAME COLUMN construction_type_ex_ante_physical TO clearing_model_type_ex_ante_physical;
ALTER TABLE Configuration RENAME COLUMN construction_type_ex_ante_commercial TO clearing_model_type_ex_ante_commercial;
ALTER TABLE Configuration RENAME COLUMN construction_type_ex_post_physical TO clearing_model_type_ex_post_physical;
ALTER TABLE Configuration RENAME COLUMN construction_type_ex_post_commercial TO clearing_model_type_ex_post_commercial;
ALTER TABLE Configuration RENAME COLUMN vr_curveguide_data_source TO virtual_reservoir_waveguide_source;
ALTER TABLE Configuration RENAME COLUMN vr_curveguide_data_format TO waveguide_user_provided_source;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_ante_physical_type TO clearing_integer_variables_ex_ante_physical_type;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_ante_commercial_type TO clearing_integer_variables_ex_ante_commercial_type;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_post_physical_type TO clearing_integer_variables_ex_post_physical_type;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_post_commercial_type TO clearing_integer_variables_ex_post_commercial_type;
