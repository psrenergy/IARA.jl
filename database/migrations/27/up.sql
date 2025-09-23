PRAGMA user_version = 27;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN nash_equilibrium_strategy INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN nash_equilibrium_initialization INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN max_iteration_nash_equilibrium INTEGER NOT NULL DEFAULT 0;
