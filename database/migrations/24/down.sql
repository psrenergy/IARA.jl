PRAGMA user_version = 23;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP COLUMN nash_equilibrium_strategy;
ALTER TABLE Configuration DROP COLUMN nash_equilibrium_initialization;
ALTER TABLE Configuration DROP COLUMN max_iteration_nash_equilibrium;