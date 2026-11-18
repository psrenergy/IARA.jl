PRAGMA user_version = 42;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN supply_function_equilibrium_max_curve_points INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN market_clearing_read_cuts_once_in_cyclic_graph INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN market_clearing_clear_solver_data INTEGER NOT NULL DEFAULT 0;
ALTER TABLE Configuration ADD COLUMN train_mincost_forward_pass_max_depth INTEGER NOT NULL DEFAULT 0;
