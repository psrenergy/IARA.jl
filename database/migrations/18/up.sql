PRAGMA user_version = 18;
PRAGMA foreign_keys = ON;

ALTER TABLE DemandUnit RENAME COLUMN curtailment_cost TO curtailment_cost_flexible_demand;
ALTER TABLE DemandUnit RENAME COLUMN max_shift_up TO max_shift_up_flexible_demand;
ALTER TABLE DemandUnit RENAME COLUMN max_shift_down TO max_shift_down_flexible_demand;
ALTER TABLE DemandUnit RENAME COLUMN max_curtailment TO max_curtailment_flexible_demand;
