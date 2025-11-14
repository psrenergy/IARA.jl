PRAGMA user_version = 33;

ALTER TABLE AssetOwner ADD COLUMN minimum_virtual_reservoir_purchase_bid_quantity_in_mw REAL NOT NULL DEFAULT 0.0;
