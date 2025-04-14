PRAGMA user_version = 6;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP COLUMN train_mincost_time_limit_sec;
ALTER TABLE Configuration RENAME COLUMN train_mincost_iteration_limit TO iteration_limit;
