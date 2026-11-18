PRAGMA user_version = 41;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP COLUMN supply_function_equilibrium_max_curve_points;
ALTER TABLE Configuration DROP COLUMN market_clearing_read_cuts_once_in_cyclic_graph;
ALTER TABLE Configuration DROP COLUMN market_clearing_clear_solver_data;
ALTER TABLE Configuration DROP COLUMN train_mincost_forward_pass_max_depth;
