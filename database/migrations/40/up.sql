PRAGMA user_version = 40;
PRAGMA foreign_keys = ON;

ALTER TABLE AssetOwner ADD COLUMN supply_function_equilibrium_weight REAL NOT NULL DEFAULT 20.0;

UPDATE AssetOwner SET supply_function_equilibrium_weight =
    (SELECT supply_function_equilibrium_price_taker_weight FROM Configuration LIMIT 1);

ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_price_taker_weight;
