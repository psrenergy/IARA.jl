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

ALTER TABLE ThermalPlant 
ADD COLUMN temp_commitment_initial_condition INTEGER NOT NULL DEFAULT 2;

UPDATE ThermalPlant SET temp_commitment_initial_condition = commitment_initial_condition
WHERE commitment_initial_condition IS NOT NULL;

ALTER TABLE ThermalPlant
DROP COLUMN commitment_initial_condition;

ALTER TABLE ThermalPlant
RENAME COLUMN temp_commitment_initial_condition TO commitment_initial_condition;

DROP TABLE Reserve;
DROP TABLE Reserve_time_series_files;
DROP TABLE Reserve_vector_thermal_plant;
DROP TABLE Reserve_vector_hydro_plant;
DROP TABLE Reserve_vector_battery;