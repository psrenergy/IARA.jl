PRAGMA user_version = 1;


-- Renaming

ALTER TABLE Configuration RENAME COLUMN number_of_periods TO number_of_stages;
ALTER TABLE Configuration RENAME COLUMN period_type TO stage_type;
ALTER TABLE Configuration RENAME COLUMN number_of_subperiods TO number_of_blocks;
ALTER TABLE Configuration RENAME COLUMN hydro_balance_subperiod_resolution TO hydro_balance_block_resolution;
ALTER TABLE Configuration RENAME COLUMN loop_subperiods_for_thermal_constraints TO loop_blocks_for_thermal_constraints;
ALTER TABLE Configuration RENAME COLUMN cycle_duration_in_hours TO yearly_duration_in_hours;
ALTER TABLE Configuration RENAME COLUMN cycle_discount_rate TO yearly_discount_rate;

ALTER TABLE Configuration_vector_subperiod_duration RENAME TO Configuration_vector_block_duration;
ALTER TABLE Configuration_vector_block_duration RENAME COLUMN subperiod_duration_in_hours TO block_duration_in_hours;
ALTER TABLE Configuration_time_series_files RENAME COLUMN hour_subperiod_map TO hour_block_map;

ALTER TABLE BiddingGroup RENAME COLUMN independent_bid_max_segments TO simple_bid_max_segments;
ALTER TABLE BiddingGroup RENAME COLUMN profile_bid_max_profiles TO multihour_bid_max_profiles;

ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN quantity_offer_profile TO quantity_offer_multihour;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN price_offer_profile TO price_offer_multihour;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN parent_profile TO parent_profile_multihour;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN complementary_grouping_profile TO complementary_grouping_multihour;
ALTER TABLE BiddingGroup_time_series_files RENAME COLUMN minimum_activation_level_profile TO minimum_activation_level_multihour;

ALTER TABLE ThermalUnit RENAME TO ThermalPlant;
ALTER TABLE ThermalUnit_time_series_parameters RENAME TO ThermalPlant_time_series_parameters;

ALTER TABLE HydroUnit RENAME TO HydroPlant;
ALTER TABLE HydroPlant RENAME COLUMN hydrounit_turbine_to TO hydroplant_turbine_to;
ALTER TABLE HydroPlant RENAME COLUMN hydrounit_spill_to TO hydroplant_spill_to;
ALTER TABLE HydroUnit_time_series_parameters RENAME TO HydroPlant_time_series_parameters;
ALTER TABLE HydroUnit_time_series_files RENAME TO HydroPlant_time_series_files;

ALTER TABLE VirtualReservoir_vector_hydro_unit RENAME TO VirtualReservoir_vector_hydro_plant;
ALTER TABLE VirtualReservoir_vector_hydro_plant RENAME COLUMN hydrounit_id TO hydroplant_id;

ALTER TABLE RenewableUnit RENAME TO RenewablePlant;
ALTER TABLE RenewableUnit_time_series_parameters RENAME TO RenewablePlant_time_series_parameters;   
ALTER TABLE RenewableUnit_time_series_files RENAME TO RenewablePlant_time_series_files;

ALTER TABLE BatteryUnit RENAME TO Battery;
ALTER TABLE BatteryUnit_time_series_parameters RENAME TO Battery_time_series_parameters;

ALTER TABLE DemandUnit RENAME TO Demand;
ALTER TABLE Demand RENAME COLUMN demand_unit_type TO demand_type;
ALTER TABLE DemandUnit_time_series_parameters RENAME TO Demand_time_series_parameters;
ALTER TABLE DemandUnit_time_series_files RENAME TO Demand_time_series_files;


-- end renaming

ALTER TABLE Configuration DROP COLUMN clearing_model_type_ex_ante_physical;
ALTER TABLE Configuration DROP COLUMN clearing_model_type_ex_ante_commercial;
ALTER TABLE Configuration DROP COLUMN clearing_model_type_ex_post_physical;
ALTER TABLE Configuration DROP COLUMN clearing_model_type_ex_post_commercial;
ALTER TABLE Configuration DROP COLUMN use_fcf_in_clearing;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_ante_physical_type;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_ante_commercial_type;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_post_physical_type;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_post_commercial_type;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_ante_commercial_source;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_post_physical_source;
ALTER TABLE Configuration DROP COLUMN clearing_integer_variables_ex_post_commercial_source;
ALTER TABLE Configuration DROP COLUMN spot_price_floor;
ALTER TABLE Configuration DROP COLUMN spot_price_cap;

ALTER TABLE Configuration ADD COLUMN temp_number_of_stages INTEGER;
ALTER TABLE Configuration ADD COLUMN temp_number_of_scenarios INTEGER;
ALTER TABLE Configuration ADD COLUMN temp_number_of_blocks INTEGER;
ALTER TABLE Configuration ADD COLUMN temp_demand_deficit_cost REAL;
ALTER TABLE Configuration ADD COLUMN temp_policy_graph_type INTEGER NOT NULL DEFAULT 1;

UPDATE Configuration SET temp_number_of_stages = number_of_stages;
UPDATE Configuration SET temp_number_of_scenarios = number_of_scenarios;
UPDATE Configuration SET temp_number_of_blocks = number_of_blocks;
UPDATE Configuration SET temp_demand_deficit_cost = demand_deficit_cost;
UPDATE Configuration SET temp_policy_graph_type = policy_graph_type;

ALTER TABLE Configuration DROP COLUMN number_of_stages;
ALTER TABLE Configuration DROP COLUMN number_of_scenarios;
ALTER TABLE Configuration DROP COLUMN number_of_blocks;
ALTER TABLE Configuration DROP COLUMN demand_deficit_cost;
ALTER TABLE Configuration DROP COLUMN policy_graph_type;

ALTER TABLE Configuration RENAME COLUMN temp_number_of_stages TO number_of_stages;
ALTER TABLE Configuration RENAME COLUMN temp_number_of_scenarios TO number_of_scenarios;
ALTER TABLE Configuration RENAME COLUMN temp_number_of_blocks TO number_of_blocks;
ALTER TABLE Configuration RENAME COLUMN temp_demand_deficit_cost TO demand_deficit_cost;
ALTER TABLE Configuration RENAME COLUMN temp_policy_graph_type TO policy_graph_type;

ALTER TABLE ThermalPlant
ADD COLUMN temp_commitment_initial_condition INTEGER;

UPDATE ThermalPlant SET temp_commitment_initial_condition = commitment_initial_condition
WHERE commitment_initial_condition IS NOT 2;

ALTER TABLE ThermalPlant
DROP COLUMN commitment_initial_condition;

ALTER TABLE ThermalPlant
RENAME COLUMN temp_commitment_initial_condition TO commitment_initial_condition;

ALTER TABLE Configuration ADD COLUMN run_mode INTEGER NOT NULL DEFAULT 0;

ALTER TABLE Configuration DROP number_of_bid_segments_for_file_template;
ALTER TABLE Configuration DROP number_of_bid_segments_for_virtual_reservoir_file_template;
ALTER TABLE Configuration DROP number_of_profiles_for_file_template;
ALTER TABLE Configuration DROP number_of_complementary_groups_for_file_template;
ALTER TABLE Configuration DROP reservoirs_physical_virtual_correspondence_type;
ALTER TABLE Configuration DROP COLUMN virtual_reservoir_waveguide_source;
ALTER TABLE Configuration DROP COLUMN waveguide_user_provided_source;

ALTER TABLE VirtualReservoir DROP COLUMN number_of_waveguide_points_for_file_template;

DROP TABLE HydroUnit_vector_waveguide;

CREATE TABLE Reserve (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    constraint_type INTEGER NOT NULL,
    direction INTEGER NOT NULL,
    violation_cost REAL NOT NULL,
    angular_coefficient REAL,
    linear_coefficient REAL
) STRICT;

CREATE TABLE Reserve_time_series_files (
    reserve_requirement TEXT NOT NULL
) STRICT;

CREATE TABLE Reserve_vector_thermal_plant (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    thermalplant_id INTEGER,
    FOREIGN KEY(id) REFERENCES Reserve(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(thermalplant_id) REFERENCES ThermalPlant(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

CREATE TABLE Reserve_vector_hydro_plant (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    hydroplant_id INTEGER,
    FOREIGN KEY(id) REFERENCES Reserve(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(hydroplant_id) REFERENCES HydroPlant(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

CREATE TABLE Reserve_vector_battery (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    battery_id INTEGER,
    FOREIGN KEY(id) REFERENCES Reserve(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(battery_id) REFERENCES Battery(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

DROP TABLE Configuration_vector_expected_number_of_repeats_per_node;
