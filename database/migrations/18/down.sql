PRAGMA user_version = 17;
PRAGMA foreign_keys = ON;

ALTER TABLE DemandUnit RENAME COLUMN curtailment_cost_flexible_demand TO curtailment_cost;
ALTER TABLE DemandUnit RENAME COLUMN max_shift_up_flexible_demand TO max_shift_up;
ALTER TABLE DemandUnit RENAME COLUMN max_shift_down_flexible_demand TO max_shift_down;
ALTER TABLE DemandUnit RENAME COLUMN max_curtailment_flexible_demand TO max_curtailment;