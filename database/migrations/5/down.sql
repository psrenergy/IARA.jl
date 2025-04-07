PRAGMA user_version = 4;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration DROP COLUMN language;
ALTER TABLE Configuration DROP COLUMN time_limit;
