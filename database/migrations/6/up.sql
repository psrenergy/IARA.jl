PRAGMA user_version = 6;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN train_mincost_time_limit_sec INTEGER DEFAULT 300;
ALTER TABLE Configuration RENAME COLUMN iteration_limit TO train_mincost_iteration_limit;
