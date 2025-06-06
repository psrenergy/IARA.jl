PRAGMA user_version = 11;
PRAGMA foreign_keys = ON;

CREATE TABLE AssetOwner_vector_account_markup (
    id INTEGER, 
    vector_index INTEGER NOT NULL,
    virtual_reservoir_energy_account_upper_bound REAL NOT NULL,
    risk_factor_for_virtual_reservoir_bids REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES AssetOwner(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

ALTER TABLE AssetOwner ADD COLUMN purchase_discount_rate REAL;

DROP TABLE IF EXISTS AssetOwner_vector_markup;