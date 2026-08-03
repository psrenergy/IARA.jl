PRAGMA user_version = 36;

CREATE TABLE Configuration_vector_subperiod_duration_old (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    subperiod_duration_in_hours REAL,
    FOREIGN KEY(id) REFERENCES Configuration(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO Configuration_vector_subperiod_duration_old (id, vector_index, subperiod_duration_in_hours)
    SELECT id, vector_index, subperiod_duration_in_hours
    FROM Configuration_vector_subperiod_duration;

DROP TABLE Configuration_vector_subperiod_duration;

ALTER TABLE Configuration_vector_subperiod_duration_old
    RENAME TO Configuration_vector_subperiod_duration;

CREATE TABLE Configuration_vector_expected_number_of_repeats_per_node_old (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    expected_number_of_repeats_per_node REAL,
    FOREIGN KEY(id) REFERENCES Configuration(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO Configuration_vector_expected_number_of_repeats_per_node_old
        (id, vector_index, expected_number_of_repeats_per_node)
    SELECT id, vector_index, expected_number_of_repeats_per_node
    FROM Configuration_vector_expected_number_of_repeats_per_node;

DROP TABLE Configuration_vector_expected_number_of_repeats_per_node;

ALTER TABLE Configuration_vector_expected_number_of_repeats_per_node_old
    RENAME TO Configuration_vector_expected_number_of_repeats_per_node;

CREATE TABLE AssetOwner_vector_purchase_discount_rate (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    purchase_discount_rate REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES AssetOwner(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO AssetOwner_vector_purchase_discount_rate (id, vector_index, purchase_discount_rate)
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY id ORDER BY purchase_discount_rate),
           purchase_discount_rate
    FROM AssetOwner_set_purchase_discount_rate;

DROP TABLE AssetOwner_set_purchase_discount_rate;

CREATE TABLE AssetOwner_vector_account_markup (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    virtual_reservoir_energy_account_upper_bound REAL NOT NULL,
    risk_factor_for_virtual_reservoir_bids REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES AssetOwner(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO AssetOwner_vector_account_markup
        (id, vector_index, virtual_reservoir_energy_account_upper_bound,
         risk_factor_for_virtual_reservoir_bids)
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY id
               ORDER BY virtual_reservoir_energy_account_upper_bound,
                        risk_factor_for_virtual_reservoir_bids
           ),
           virtual_reservoir_energy_account_upper_bound,
           risk_factor_for_virtual_reservoir_bids
    FROM AssetOwner_set_account_markup;

DROP TABLE AssetOwner_set_account_markup;

CREATE TABLE VirtualReservoir_vector_hydro_unit (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    hydrounit_id INTEGER,
    FOREIGN KEY(id) REFERENCES VirtualReservoir(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(hydrounit_id) REFERENCES "HydroUnit"(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO VirtualReservoir_vector_hydro_unit (id, vector_index, hydrounit_id)
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY id ORDER BY hydrounit_id),
           hydrounit_id
    FROM VirtualReservoir_set_hydro_unit;

DROP TABLE VirtualReservoir_set_hydro_unit;

CREATE TABLE VirtualReservoir_vector_asset_owner_and_parameters (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    assetowner_id INTEGER,
    inflow_allocation REAL NOT NULL,
    initial_energy_account_share REAL,
    FOREIGN KEY(id) REFERENCES VirtualReservoir(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(assetowner_id) REFERENCES AssetOwner(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO VirtualReservoir_vector_asset_owner_and_parameters
        (id, vector_index, assetowner_id, inflow_allocation, initial_energy_account_share)
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY id ORDER BY assetowner_id),
           assetowner_id,
           inflow_allocation,
           initial_energy_account_share
    FROM VirtualReservoir_set_asset_owner_and_parameters;

DROP TABLE VirtualReservoir_set_asset_owner_and_parameters;

CREATE TABLE BiddingGroup_vector_markup (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    risk_factor REAL,
    segment_fraction REAL,
    FOREIGN KEY(id) REFERENCES BiddingGroup(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO BiddingGroup_vector_markup (id, vector_index, risk_factor, segment_fraction)
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY id ORDER BY risk_factor, segment_fraction),
           risk_factor,
           segment_fraction
    FROM BiddingGroup_set_markup;

DROP TABLE BiddingGroup_set_markup;
