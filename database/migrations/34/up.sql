PRAGMA user_version = 34;

ALTER TABLE AssetOwner ADD COLUMN minimum_virtual_reservoir_purchase_bid_quantity REAL NOT NULL DEFAULT 0.0;
