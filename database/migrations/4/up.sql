PRAGMA user_version = 4;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP number_of_bid_segments_for_file_template;
ALTER TABLE Configuration DROP number_of_bid_segments_for_virtual_reservoir_file_template;
ALTER TABLE Configuration DROP number_of_profiles_for_file_template;
ALTER TABLE Configuration DROP number_of_complementary_groups_for_file_template;

ALTER TABLE Configuration ADD COLUMN network_representation_mincost INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN network_representation_ex_ante_physical INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN network_representation_ex_ante_commercial INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN network_representation_ex_post_physical INTEGER DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN network_representation_ex_post_commercial INTEGER DEFAULT 0;

ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_mincost_type TO integer_variable_representation_mincost;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_ante_physical_type TO integer_variable_representation_ex_ante_physical;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_ante_commercial_type TO integer_variable_representation_ex_ante_commercial;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_post_physical_type TO integer_variable_representation_ex_post_physical;
ALTER TABLE Configuration RENAME COLUMN integer_variable_representation_ex_post_commercial_type TO integer_variable_representation_ex_post_commercial;

CREATE TABLE Interconnection (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    zone_to INTEGER,
    zone_from INTEGER,
    FOREIGN KEY(zone_to) REFERENCES Zone(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(zone_from) REFERENCES Zone(id)ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE Interconnection_time_series_parameters (
    id INTEGER, 
    date_time TEXT NOT NULL,
    existing INTEGER,
    capacity_to REAL,
    capacity_from REAL,
    FOREIGN KEY(id) REFERENCES Interconnection(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, date_time)
) STRICT;