PRAGMA user_version = 8;
PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;
CREATE TABLE DemandUnit_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    demand_unit_type INTEGER NOT NULL DEFAULT 0,
    max_shift_up REAL,
    max_shift_down REAL,
    curtailment_cost REAL,
    max_curtailment REAL,
    bus_id INTEGER,
    max_demand REAL NOT NULL,
    biddinggroup_id INTEGER,
    FOREIGN KEY(bus_id) REFERENCES Bus(id) ON UPDATE CASCADE ON DELETE
    SET NULL,
        FOREIGN KEY(biddinggroup_id) REFERENCES BiddingGroup(id) ON UPDATE CASCADE ON DELETE
    SET NULL
);
INSERT INTO DemandUnit_new (
        id,
        label,
        demand_unit_type,
        max_shift_up,
        max_shift_down,
        curtailment_cost,
        max_curtailment,
        bus_id,
        max_demand
    )
SELECT id,
    label,
    demand_unit_type,
    max_shift_up,
    max_shift_down,
    curtailment_cost,
    max_curtailment,
    bus_id,
    max_demand
FROM DemandUnit;
DROP TABLE DemandUnit;
ALTER TABLE DemandUnit_new
    RENAME TO DemandUnit;
PRAGMA foreign_key_check;
COMMIT;
-- Enable foreign key constraints
PRAGMA foreign_keys = ON;