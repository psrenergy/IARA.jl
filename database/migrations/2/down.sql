PRAGMA user_version = 1;

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
ALTER TABLE ThermalPlant
ADD COLUMN temp_commitment_initial_condition INTEGER;

UPDATE ThermalPlant SET temp_commitment_initial_condition = commitment_initial_condition
WHERE commitment_initial_condition IS NOT 2;

ALTER TABLE ThermalPlant
DROP COLUMN commitment_initial_condition;

ALTER TABLE ThermalPlant
RENAME COLUMN temp_commitment_initial_condition TO commitment_initial_condition;


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