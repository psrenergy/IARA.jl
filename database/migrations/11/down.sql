PRAGMA user_version = 10;
PRAGMA foreign_keys = ON;

DROP TABLE AssetOwner_vector_account_markup;
ALTER TABLE AssetOwner DROP COLUMN purchase_discount_rate;

CREATE TABLE AssetOwner_vector_markup (
    id INTEGER, 
    vector_index INTEGER NOT NULL,
    risk_factor REAL,
    segment_fraction REAL,
    FOREIGN KEY(id) REFERENCES AssetOwner(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;
