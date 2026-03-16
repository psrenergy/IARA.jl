PRAGMA user_version = 36;

ALTER TABLE Configuration ADD COLUMN cvar_alpha REAL NOT NULL DEFAULT 1.0;
ALTER TABLE Configuration ADD COLUMN cvar_lambda REAL NOT NULL DEFAULT 0.0;
