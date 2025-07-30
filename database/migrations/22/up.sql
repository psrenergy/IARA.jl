PRAGMA user_version = 22;
PRAGMA foreign_keys = ON;

CREATE TABLE AssetOwner_vector_purchase_discount_rate (
    id INTEGER, 
    vector_index INTEGER NOT NULL,
    purchase_discount_rate REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES AssetOwner(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

INSERT INTO AssetOwner_vector_purchase_discount_rate (id, vector_index, purchase_discount_rate) 
    SELECT id AS id, 
    1 AS vector_index,
    purchase_discount_rate AS purchase_discount_rate
FROM AssetOwner;

ALTER TABLE AssetOwner DROP COLUMN purchase_discount_rate;