PRAGMA user_version = 12;
PRAGMA foreign_keys = ON;

ALTER TABLE BiddingGroup ADD COLUMN ex_post_adjust_mode INTEGER NOT NULL DEFAULT 1;