PRAGMA user_version = 19;
PRAGMA foreign_keys = ON;

UPDATE Configuration SET renewable_scenarios_files = 1 WHERE renewable_scenarios_files = 0;
UPDATE Configuration SET demand_scenarios_files = 1 WHERE demand_scenarios_files = 0;