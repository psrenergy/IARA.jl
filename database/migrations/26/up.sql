PRAGMA user_version = 26;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN nash_equilibrium_strategy INTEGER;
ALTER TABLE Configuration ADD COLUMN nash_equilibrium_initialization INTEGER;
ALTER TABLE Configuration ADD COLUMN max_iteration_nash_equilibrium INTEGER;
