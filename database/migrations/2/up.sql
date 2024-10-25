PRAGMA user_version = 2;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN clearing_model_type_ex_ante_physical INTEGER DEFAULT -1;
ALTER TABLE Configuration ADD COLUMN clearing_model_type_ex_ante_commercial INTEGER DEFAULT -1;
ALTER TABLE Configuration ADD COLUMN clearing_model_type_ex_post_physical INTEGER DEFAULT -1;
ALTER TABLE Configuration ADD COLUMN clearing_model_type_ex_post_commercial INTEGER DEFAULT -1;
ALTER TABLE Configuration ADD COLUMN use_fcf_in_clearing INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_ante_physical_type INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_ante_commercial_type INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_post_physical_type INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_post_commercial_type INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_ante_commercial_source INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_post_physical_source INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN clearing_integer_variables_ex_post_commercial_source INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN spot_price_floor REAL;
ALTER TABLE Configuration ADD COLUMN spot_price_cap REAL;
ALTER TABLE Configuration ADD number_of_bid_segments_for_file_template INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD number_of_bid_segments_for_virtual_reservoir_file_template INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD number_of_profiles_for_file_template INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD number_of_complementary_groups_for_file_template INTEGER DEFAULT 0;

ALTER TABLE ThermalPlant 
ADD COLUMN temp_commitment_initial_condition INTEGER NOT NULL DEFAULT 2;

UPDATE ThermalPlant SET temp_commitment_initial_condition = commitment_initial_condition
WHERE commitment_initial_condition IS NOT NULL;

ALTER TABLE ThermalPlant
DROP COLUMN commitment_initial_condition;

ALTER TABLE ThermalPlant
RENAME COLUMN temp_commitment_initial_condition TO commitment_initial_condition;

ALTER TABLE Configuration ADD COLUMN virtual_reservoir_waveguide_source INTEGER DEFAULT 1;
ALTER TABLE Configuration ADD COLUMN waveguide_user_provided_source INTEGER DEFAULT 0;

ALTER TABLE VirtualReservoir ADD COLUMN number_of_waveguide_points_for_file_template INTEGER;

CREATE TABLE HydroUnit_vector_waveguide (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    waveguide_volume REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES HydroUnit(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

DROP TABLE Reserve;
DROP TABLE Reserve_time_series_files;
DROP TABLE Reserve_vector_thermal_plant;
DROP TABLE Reserve_vector_hydro_plant;
DROP TABLE Reserve_vector_battery;

-- Renaming

ALTER TABLE Configuration RENAME COLUMN number_of_stages TO number_of_periods;
ALTER TABLE Configuration RENAME COLUMN stage_type TO period_type;

ALTER TABLE Configuration RENAME COLUMN number_of_blocks TO number_of_subperiods;
ALTER TABLE Configuration RENAME COLUMN hydro_balance_block_resolution TO hydro_balance_subperiod_resolution;
ALTER TABLE Configuration RENAME COLUMN loop_blocks_for_thermal_constraints TO loop_subperiods_for_thermal_constraints;
ALTER TABLE Configuration_vector_block_duration RENAME TO Configuration_vector_subperiod_duration;
ALTER TABLE Configuration_vector_subperiod_duration RENAME COLUMN block_duration_in_hours TO subperiod_duration_in_hours;
ALTER TABLE Configuration_time_series_files RENAME COLUMN hour_block_map TO hour_subperiod_map;


ALTER TABLE BiddingGroup RENAME COLUMN simple_bid_max_segments TO independent_bid_max_segments;
ALTER TABLE BiddingGroup RENAME COLUMN multihour_bid_max_profiles TO profile_bid_max_profiles;

ALTER TABLE ThermalPlant RENAME TO ThermalUnit;
ALTER TABLE ThermalPlant_time_series_parameters RENAME TO ThermalUnit_time_series_parameters;

ALTER TABLE HydroPlant RENAME TO HydroUnit;
ALTER TABLE HydroUnit RENAME COLUMN hydroplant_turbine_to TO hydrounit_turbine_to;
ALTER TABLE HydroUnit RENAME COLUMN hydroplant_spill_to TO hydrounit_spill_to; 
ALTER TABLE HydroPlant_time_series_parameters RENAME TO HydroUnit_time_series_parameters;
ALTER TABLE HydroPlant_time_series_files RENAME TO HydroUnit_time_series_files;

ALTER TABLE VirtualReservoir_vector_hydro_plant RENAME TO VirtualReservoir_vector_hydro_unit;
ALTER TABLE VirtualReservoir_vector_hydro_unit RENAME COLUMN hydroplant_id TO hydrounit_id;

ALTER TABLE RenewablePlant RENAME TO RenewableUnit;
ALTER TABLE RenewablePlant_time_series_parameters RENAME TO RenewableUnit_time_series_parameters;
ALTER TABLE RenewablePlant_time_series_files RENAME TO RenewableUnit_time_series_files;

ALTER TABLE Battery RENAME TO BatteryUnit;
ALTER TABLE Battery_time_series_parameters RENAME TO BatteryUnit_time_series_parameters;

ALTER TABLE Demand RENAME TO DemandUnit;
ALTER TABLE DemandUnit RENAME COLUMN demand_type TO demand_unit_type;
ALTER TABLE Demand_time_series_parameters RENAME TO DemandUnit_time_series_parameters;
ALTER TABLE Demand_time_series_files RENAME TO DemandUnit_time_series_files;


