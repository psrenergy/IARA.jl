#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

using Dates
using DataFrames

# Case dimensions
# ---------------
number_of_periods = 3
number_of_scenarios = 4
number_of_subperiods = 5
subperiod_duration_in_hours = 1.0

# Conversion constants
# --------------------
m3_per_second_to_hm3 = (3600 / 1e6) * subperiod_duration_in_hours
MW_to_GWh = subperiod_duration_in_hours * 1e-3

# Create the database
# -------------------
db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    initial_date_time = "2020-01-01T00:00:00",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    use_binary_variables = IARA.Configurations_BinaryVariableUsage.USE,
    cycle_discount_rate = 0.0,
    cycle_duration_in_hours = 8760.0,
    demand_deficit_cost = 0.5,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

IARA.add_thermal_unit!(db;
    label = "max_uptime_plant",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.ThermalUnit_Existence.EXISTS)],
        startup_cost = [0.0],
        min_generation = [0.0],
        max_generation = [5.0],
        om_cost = [1.0] / 1e3,
    ),
    has_commitment = Int(IARA.ThermalUnit_HasCommitment.HAS_COMMITMENT),
    max_uptime = 3.0,
    uptime_initial_condition = 2.0,
    bus_id = "bus_1",
)

IARA.add_thermal_unit!(db;
    label = "min_downtime_plant",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.ThermalUnit_Existence.EXISTS)],
        startup_cost = [0.0],
        min_generation = [0.0],
        max_generation = [5.0],
        om_cost = [1.0] / 1e3,
    ),
    has_commitment = Int(IARA.ThermalUnit_HasCommitment.HAS_COMMITMENT),
    min_downtime = 3.0,
    downtime_initial_condition = 1.0,
    bus_id = "bus_1",
)

IARA.add_thermal_unit!(db;
    label = "unconstrained_plant",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.ThermalUnit_Existence.EXISTS)],
        startup_cost = [0.0],
        min_generation = [0.0],
        max_generation = [15.0],
        om_cost = [3.0] / 1e3,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
)

IARA.add_thermal_unit!(db;
    label = "min_uptime_plant",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.ThermalUnit_Existence.EXISTS)],
        startup_cost = [0.0],
        min_generation = [3.0],
        max_generation = [5.0],
        om_cost = [4.0] / 1e3,
    ),
    has_commitment = Int(IARA.ThermalUnit_HasCommitment.HAS_COMMITMENT),
    min_uptime = 2.0,
    commitment_initial_condition = Int(IARA.ThermalUnit_CommitmentInitialCondition.ON),
    uptime_initial_condition = 1.0,
    bus_id = "bus_1",
)

IARA.add_demand_unit!(db;
    label = "dem_1",
    demand_unit_type = IARA.DemandUnit_DemandType.INELASTIC,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
    ),
    max_shift_up = 0.0,
    max_shift_down = 0.0,
    curtailment_cost = 0.0,
    max_curtailment = 0.0,
    bus_id = "bus_1",
)

# Create and link CSV files
# -------------------------

demand = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods) .+ 15 * MW_to_GWh
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand = "demand",
)

IARA.close_study!(db)
