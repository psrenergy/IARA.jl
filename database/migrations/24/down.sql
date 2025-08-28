PRAGMA user_version = 23;
PRAGMA foreign_keys = ON;

ALTER TABLE HydroUnit DROP COLUMN initial_volume_variation_type;
ALTER TABLE GaugingStation DROP COLUMN inflow_initial_state_variation_type;

ALTER TABLE GaugingStation_time_series_files DROP COLUMN inflow_initial_state_by_scenario;
ALTER TABLE HydroUnit_time_series_files DROP COLUMN initial_volume_by_scenario;

ALTER TABLE GaugingStation_time_series_files ADD COLUMN temp_inflow_noise TEXT NOT NULL;
ALTER TABLE GaugingStation_time_series_files ADD COLUMN temp_parp_coefficients TEXT NOT NULL;
ALTER TABLE GaugingStation_time_series_files ADD COLUMN temp_inflow_period_average TEXT NOT NULL;
ALTER TABLE GaugingStation_time_series_files ADD COLUMN temp_inflow_period_std_dev TEXT NOT NULL;
UPDATE GaugingStation_time_series_files SET temp_inflow_noise = inflow_noise WHERE inflow_noise IS NOT NULL;
UPDATE GaugingStation_time_series_files SET temp_parp_coefficients = parp_coefficients WHERE parp_coefficients IS NOT NULL;
UPDATE GaugingStation_time_series_files SET temp_inflow_period_average = inflow_period_average WHERE inflow_period_average IS NOT NULL;
UPDATE GaugingStation_time_series_files SET temp_inflow_period_std_dev = inflow_period_std_dev WHERE inflow_period_std_dev IS NOT NULL;
ALTER TABLE GaugingStation_time_series_files DROP COLUMN inflow_noise;
ALTER TABLE GaugingStation_time_series_files DROP COLUMN parp_coefficients;
ALTER TABLE GaugingStation_time_series_files DROP COLUMN inflow_period_average;
ALTER TABLE GaugingStation_time_series_files DROP COLUMN inflow_period_std_dev;
ALTER TABLE GaugingStation_time_series_files RENAME COLUMN temp_inflow_noise TO inflow_noise;
ALTER TABLE GaugingStation_time_series_files RENAME COLUMN temp_parp_coefficients TO parp_coefficients;
ALTER TABLE GaugingStation_time_series_files RENAME COLUMN temp_inflow_period_average TO inflow_period_average;
ALTER TABLE GaugingStation_time_series_files RENAME COLUMN temp_inflow_period_std_dev TO inflow_period_std_dev;
