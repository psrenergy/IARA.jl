PRAGMA user_version = 9;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN virtual_reservoir_initial_energy_account_share INTEGER NOT NULL DEFAULT 0;
ALTER TABLE VirtualReservoir_vector_owner_and_allocation ADD COLUMN initial_energy_account_share REAL;
ALTER TABLE VirtualReservoir_vector_owner_and_allocation RENAME TO VirtualReservoir_vector_asset_owner_and_parameters;