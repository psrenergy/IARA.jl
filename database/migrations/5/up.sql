PRAGMA user_version = 5;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration ADD COLUMN language TEXT DEFAULT "en";