PRAGMA user_version = 39;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_price_taker_weight REAL NOT NULL DEFAULT 20.0;

UPDATE Configuration SET supply_function_equilibrium_price_taker_weight =
    (SELECT supply_function_equilibrium_weight FROM AssetOwner LIMIT 1);

ALTER TABLE AssetOwner DROP COLUMN supply_function_equilibrium_weight;
