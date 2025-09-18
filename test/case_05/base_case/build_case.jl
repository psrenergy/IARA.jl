
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
number_of_subperiods = 2
subperiod_duration_in_hours = 1.0

# Conversion constants
# --------------------
m3_per_second_to_hm3 = (3600 / 1e6) * subperiod_duration_in_hours

# Create the database
# -------------------

db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    initial_date_time = "2020-01-01T00:00:00",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    cycle_discount_rate = 0.36,
    cycle_duration_in_hours = 8760.0,
    demand_deficit_cost = 0.5,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.FIT_PARP_MODEL_FROM_DATA,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")
IARA.add_bus!(db; label = "bus_2", zone_id = "zone_1")

IARA.add_renewable_unit!(db;
    label = "gnd_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.RenewableUnit_Existence.EXISTS)],
        max_generation = [4.0],
        om_cost = [0.0],
        curtailment_cost = [0.1],
    ),
    technology_type = 1,
    bus_id = "bus_2",
)

# 10 years of monthly historical inflow starting from 2001-01-01
historical_inflow_dates = [DateTime(year, month, 1) for month in 1:12, year in 2001:2010] |> vec
historical_inflow_values = [65.6,
    99.2,
    87.0,
    67.2,
    52.5,
    46.8,
    38.7,
    26.9,
    21.2,
    30.4,
    36.5,
    56.3,
    93.1,
    82.0,
    79.4,
    52.6,
    43.6,
    39.1,
    29.7,
    23.7,
    27.4,
    32.5,
    40.3,
    79.0,
    65.1,
    68.2,
    82.3,
    70.1,
    40.7,
    32.4,
    28.5,
    24.2,
    25.8,
    36.4,
    40.5,
    79.1,
    132.5,
    127.3,
    72.1,
    49.7,
    40.8,
    33.7,
    32.7,
    26.5,
    18.5,
    18.8,
    33.2,
    41.8,
    53.2,
    88.6,
    89.2,
    73.1,
    50.8,
    39.4,
    29.7,
    31.9,
    22.8,
    29.3,
    36.6,
    53.4,
    76.3,
    92.2,
    66.5,
    68.4,
    43.9,
    35.8,
    39.3,
    34.2,
    44.5,
    51.8,
    52.6,
    86.8,
    99.1,
    83.3,
    75.4,
    64.0,
    41.3,
    32.8,
    28.9,
    22.3,
    19.3,
    30.7,
    40.8,
    62.1,
    106.4,
    69.9,
    120.5,
    77.1,
    47.2,
    39.2,
    34.0,
    33.7,
    23.2,
    34.9,
    38.0,
    62.0,
    102.2,
    69.0,
    51.6,
    44.8,
    41.7,
    53.6,
    36.9,
    24.0,
    20.5,
    21.0,
    32.3,
    38.7,
    65.2,
    78.7,
    68.7,
    71.7,
    40.7,
    53.4,
    43.1,
    26.7,
    23.7,
    33.4,
    31.7,
    55.5,
]
historical_inflow_values ./= maximum(historical_inflow_values)
IARA.add_gauging_station!(db;
    label = "gs_1",
    historical_inflow = DataFrame(;
        date_time = historical_inflow_dates,
        historical_inflow = historical_inflow_values,
    ),
)

IARA.add_hydro_unit!(db;
    label = "hyd_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.HydroUnit_Existence.EXISTS)],
        production_factor = [1.0],
        min_generation = [0.0],
        max_generation = [3.5],
        max_turbining = [3.5],
        min_volume = [0.0],
        max_volume = [30.0 * m3_per_second_to_hm3],
        min_outflow = [0.0],
        om_cost = [0.0],
    ),
    initial_volume = 12.0 * m3_per_second_to_hm3,
    bus_id = "bus_2",
    gaugingstation_id = "gs_1",
    spillage_cost = 1e-3,
)

IARA.add_thermal_unit!(db;
    label = "ter_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 1.0 / 1e3,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
)

max_demand = 10.0

IARA.add_demand_unit!(db;
    label = "dem_1",
    demand_unit_type = IARA.DemandUnit_DemandType.INELASTIC,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
    ),
    max_shift_up_flexible_demand = 0.0,
    max_shift_down_flexible_demand = 0.0,
    curtailment_cost_flexible_demand = 0.0,
    max_curtailment_flexible_demand = 0.0,
    bus_id = "bus_1",
    max_demand = max_demand,
)

IARA.add_dc_line!(db;
    label = "dc_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DCLine_Existence.EXISTS)],
        capacity_to = [5.5],
        capacity_from = [5.5],
    ),
    bus_from = "bus_1",
    bus_to = "bus_2",
)

# Create and link CSV files
# -------------------------

renewable_generation = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
for scen in 1:number_of_scenarios
    renewable_generation[:, :, scen, :] .+= (5 - scen) / 4
end
renewable_generation[1, 1, 3, 3] += 1.56794 / 4.0
IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    renewable_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["gnd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

demand = ones(1, number_of_subperiods, number_of_scenarios, number_of_periods)
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_ante = "renewable_generation",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demand",
)

IARA.close_study!(db)
