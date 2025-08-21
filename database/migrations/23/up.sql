PRAGMA user_version = 23;
PRAGMA foreign_keys = ON;

CREATE TABLE GaugingStation_time_series_files (
    inflow_noise TEXT NOT NULL,
    parp_coefficients TEXT NOT NULL,
    inflow_period_average TEXT NOT NULL,
    inflow_period_std_dev TEXT NOT NULL
) STRICT;
