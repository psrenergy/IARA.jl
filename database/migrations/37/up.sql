PRAGMA user_version = 37;

ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_price_taker_weight REAL NOT NULL DEFAULT 10.0;
