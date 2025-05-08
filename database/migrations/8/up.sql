PRAGMA user_version = 8;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN virtual_reservoirs_initial_energy_stock_source INTEGER NOT NULL DEFAULT 0;
ALTER TABLE VirtualReservoir_vector_owner_and_allocation ADD COLUMN initial_energy_stock_share REAL;
ALTER TABLE VirtualReservoir_vector_owner_and_allocation RENAME TO VirtualReservoir_vector_asset_owner_and_parameters;