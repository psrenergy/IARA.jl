PRAGMA user_version = 37;

CREATE TABLE Configuration_vector_subperiod_duration_new (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    subperiod_duration_in_hours REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES Configuration(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO Configuration_vector_subperiod_duration_new (id, vector_index, subperiod_duration_in_hours)
    SELECT id, vector_index, subperiod_duration_in_hours
    FROM Configuration_vector_subperiod_duration;

DROP TABLE Configuration_vector_subperiod_duration;

ALTER TABLE Configuration_vector_subperiod_duration_new
    RENAME TO Configuration_vector_subperiod_duration;

CREATE TABLE Configuration_vector_expected_number_of_repeats_per_node_new (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    expected_number_of_repeats_per_node REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES Configuration(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO Configuration_vector_expected_number_of_repeats_per_node_new
        (id, vector_index, expected_number_of_repeats_per_node)
    SELECT id, vector_index, expected_number_of_repeats_per_node
    FROM Configuration_vector_expected_number_of_repeats_per_node;

DROP TABLE Configuration_vector_expected_number_of_repeats_per_node;

ALTER TABLE Configuration_vector_expected_number_of_repeats_per_node_new
    RENAME TO Configuration_vector_expected_number_of_repeats_per_node;

CREATE TABLE AssetOwner_set_purchase_discount_rate (
    id INTEGER,
    purchase_discount_rate REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES AssetOwner(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, purchase_discount_rate)
) STRICT;

INSERT INTO AssetOwner_set_purchase_discount_rate (id, purchase_discount_rate)
    SELECT id, purchase_discount_rate FROM AssetOwner_vector_purchase_discount_rate;

DROP TABLE AssetOwner_vector_purchase_discount_rate;

CREATE TABLE AssetOwner_set_account_markup (
    id INTEGER,
    virtual_reservoir_energy_account_upper_bound REAL NOT NULL,
    risk_factor_for_virtual_reservoir_bids REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES AssetOwner(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (
        id,
        virtual_reservoir_energy_account_upper_bound,
        risk_factor_for_virtual_reservoir_bids
    )
) STRICT;

INSERT INTO AssetOwner_set_account_markup
        (id, virtual_reservoir_energy_account_upper_bound, risk_factor_for_virtual_reservoir_bids)
    SELECT id, virtual_reservoir_energy_account_upper_bound, risk_factor_for_virtual_reservoir_bids
    FROM AssetOwner_vector_account_markup;

DROP TABLE AssetOwner_vector_account_markup;

CREATE TABLE VirtualReservoir_set_hydro_unit (
    id INTEGER,
    hydrounit_id INTEGER NOT NULL,
    FOREIGN KEY(id) REFERENCES VirtualReservoir(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(hydrounit_id) REFERENCES "HydroUnit"(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, hydrounit_id)
) STRICT;

INSERT INTO VirtualReservoir_set_hydro_unit (id, hydrounit_id)
    SELECT id, hydrounit_id FROM VirtualReservoir_vector_hydro_unit;

DROP TABLE VirtualReservoir_vector_hydro_unit;

CREATE TABLE VirtualReservoir_set_asset_owner_and_parameters (
    id INTEGER,
    assetowner_id INTEGER NOT NULL,
    inflow_allocation REAL NOT NULL,
    initial_energy_account_share REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES VirtualReservoir(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(assetowner_id) REFERENCES AssetOwner(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, assetowner_id),
    UNIQUE (id, assetowner_id, inflow_allocation, initial_energy_account_share)
) STRICT;

INSERT INTO VirtualReservoir_set_asset_owner_and_parameters
        (id, assetowner_id, inflow_allocation, initial_energy_account_share)
    SELECT id, assetowner_id, inflow_allocation, initial_energy_account_share
    FROM VirtualReservoir_vector_asset_owner_and_parameters;

DROP TABLE VirtualReservoir_vector_asset_owner_and_parameters;

CREATE TABLE BiddingGroup_set_markup (
    id INTEGER,
    risk_factor REAL NOT NULL,
    segment_fraction REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES BiddingGroup(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, risk_factor, segment_fraction)
) STRICT;

INSERT INTO BiddingGroup_set_markup (id, risk_factor, segment_fraction)
    SELECT id, risk_factor, segment_fraction FROM BiddingGroup_vector_markup;

DROP TABLE BiddingGroup_vector_markup;
