PRAGMA user_version = 21;
PRAGMA foreign_keys = ON;

ALTER TABLE AssetOwner ADD COLUMN purchase_discount_rate REAL;

UPDATE AssetOwner SET purchase_discount_rate = (
    SELECT purchase_discount_rate 
    FROM AssetOwner_vector_purchase_discount_rate 
    WHERE AssetOwner.id = AssetOwner_vector_purchase_discount_rate.id AND vector_index = 1
);

DROP TABLE AssetOwner_vector_purchase_discount_rate;