PRAGMA user_version = 4;
PRAGMA foreign_keys = ON;

ALTER TABLE Configuration_time_series_files ADD COLUMN period_season_map TEXT;
