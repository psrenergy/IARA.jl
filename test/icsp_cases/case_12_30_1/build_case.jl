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

include("../build_inflow.jl")

# Case dimensions
# ---------------
# Fixed dimensions
number_of_periods = 12
number_of_scenarios = 10
number_of_subperiods = 24

# Variable dimensions
number_of_nodes = 12
subperiod_duration_in_hours = 30.0
expected_number_of_repeats_per_node = 1.0

# Create the database
# -------------------
db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    number_of_nodes = number_of_nodes,
    expected_number_of_repeats_per_node = [expected_number_of_repeats_per_node for _ in 1:number_of_nodes],
    initial_date_time = "2020-01-01T00:00:00",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.CYCLIC_WITH_SEASON_ROOT,
    cycle_discount_rate = 1.0,
    cycle_duration_in_hours = 8640.0, # 12 * 30 * 24
    demand_deficit_cost = 2000.0,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    train_mincost_time_limit_sec = 300,
    # train_mincost_iteration_limit = 1,
)

# =====================================================
# Add collection elements
# =====================================================

# Zone
# --------------------
IARA.add_zone!(db; label = "zone_1")

# Buses
# --------------------
number_of_buses = 5
bus_labels = ["SE", "S", "NE", "N", "Imperatriz"]
@assert length(bus_labels) == number_of_buses
for bus in 1:number_of_buses
    IARA.add_bus!(db; label = bus_labels[bus], zone_id = "zone_1")
end

# Hydro units
# --------------------
# One hydro unit per bus (except for Imperatriz), named after the bus
number_of_hydro_units = 4
# Maximum generation in [MW]
hydro_unit_maximum_generation = [63.1259, 18.1833, 13.7623, 10.6056]
# Initial volume in [hm^3]
hydro_unit_initial_volume = [213.909, 21.150, 46.293, 18.977]
# Maximum volume in [hm^3]
hydro_unit_max_volume = [722.583, 70.6219, 186.502, 45.8816]
@assert length(hydro_unit_maximum_generation) == number_of_hydro_units
@assert length(hydro_unit_initial_volume) == number_of_hydro_units
@assert length(hydro_unit_max_volume) == number_of_hydro_units

for h in 1:number_of_hydro_units
    IARA.add_hydro_unit!(db;
        label = "hyd_$(bus_labels[h])",
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = [Int(IARA.HydroUnit_Existence.EXISTS)],
            min_generation = [0.0],
            max_generation = [hydro_unit_maximum_generation[h]],
            production_factor = [1.0],
            max_turbining = [hydro_unit_maximum_generation[h]],
            min_volume = [0.0],
            max_volume = [hydro_unit_max_volume[h]],
            min_outflow = [0.0],
            om_cost = [0.0],
        ),
        initial_volume = hydro_unit_initial_volume[h],
        bus_id = h,
    )
end

# Thermal units
# --------------------
# SE
se_number_of_thermal_units = 43
# Maximum generation in [MW]
se_thermal_unit_maximum_generation = [
    0.91323,
    1.8765,
    0.05004,
    0.3475,
    0.3475,
    0.03892,
    0.73531,
    0.06116,
    0.35445,
    0.32665,
    0.53654,
    0.53654,
    0.20155,
    0.31414,
    0.18209,
    0.12093,
    0.28356,
    1.28297,
    1.28297,
    0.556,
    0.139,
    0.278,
    0.23491,
    0.53654,
    0.03892,
    0.278,
    0.37808,
    0.0417,
    0.23352,
    0.6116,
    0.556,
    0.35862,
    0.35862,
    0.35862,
    0.08896,
    0.4726,
    1.47062,
    1.47062,
    0.0139,
    0.27383,
    0.24325,
    0.28634,
    0.07506,
]
# Minimum generation in [MW]
se_thermal_unit_minimum_generation = [
    0.7228,
    1.5012,
    0,
    0.082427,
    0.037669,
    0,
    0,
    0,
    0.305494,
    0.277986,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0.555986,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0.099663,
    0.040032,
    0,
    0.184842,
    0,
    0,
    0,
]
# O&M cost in [$/MWh]
se_thermal_unit_om_cost = [
    21.49,
    18.96,
    937,
    194.79,
    222.22,
    140.58,
    6.27,
    505.92,
    0.01,
    112.46,
    159.97,
    250.87,
    550.66,
    188.89,
    645.3,
    150,
    145.68,
    274.54,
    253.83,
    37.8,
    51.93,
    90.69,
    131.68,
    317.98,
    152.8,
    470.34,
    317.98,
    523.35,
    730.54,
    310.41,
    730.54,
    101.33,
    140.34,
    292.49,
    610.33,
    487.56,
    122.65,
    214.48,
    1047.38,
    0.01,
    329.57,
    197.85,
    733.54,
]
@assert length(se_thermal_unit_maximum_generation) == se_number_of_thermal_units
@assert length(se_thermal_unit_minimum_generation) == se_number_of_thermal_units
@assert length(se_thermal_unit_om_cost) == se_number_of_thermal_units

# S
s_number_of_thermal_units = 17
# Maximum generation in [MW]
s_thermal_unit_maximum_generation = [
    0.09174,
    0.67415,
    0.67415,
    0.4865,
    0.22379,
    0.10008,
    0.00556,
    0.0278,
    0.139,
    0.18348,
    0.36418,
    0.50457,
    0.03336,
    0.17514,
    0.4448,
    0.0278,
    0.8896,
]
# Minimum generation in [MW]
s_thermal_unit_minimum_generation =
    [0, 0, 0, 0.2919, 0, 0.03753, 0, 0.013288, 0.03475, 0.110449, 0.205081, 0.316948, 0, 0.069027, 0.14595, 0.00695, 0]
# O&M cost in [$/MWh]
s_thermal_unit_om_cost = [
    564.57,
    219,
    219,
    50.47,
    541.93,
    154.1,
    180.51,
    218.77,
    189.54,
    143.04,
    142.86,
    116.9,
    780,
    115.9,
    115.9,
    248.31,
    141.18,
]
@assert length(s_thermal_unit_maximum_generation) == s_number_of_thermal_units
@assert length(s_thermal_unit_minimum_generation) == s_number_of_thermal_units
@assert length(s_thermal_unit_om_cost) == s_number_of_thermal_units

# NE
ne_number_of_thermal_units = 33
# Maximum generation in [MW]
ne_thermal_unit_maximum_generation = [
    0.01807,
    0.01529,
    0.04448,
    0.01529,
    0.48233,
    0.21128,
    0.2085,
    0.01807,
    0.02085,
    0.3058,
    0.3058,
    0.01807,
    0.02085,
    0.19182,
    0.48233,
    0.20711,
    0.20711,
    0.02085,
    0.14178,
    0.02085,
    0.23352,
    0.01807,
    0.01807,
    0.14317,
    0.18904,
    0.07367,
    0.09174,
    0.25854,
    0.0695,
    0.21684,
    0.23769,
    0.74087,
    0.44897,
]
# Minimum generation in [MW]
ne_thermal_unit_minimum_generation = [
    0,
    0,
    0,
    0,
    0.000973,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0.30997,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0.484832,
    0,
]
# O&M cost in [$/MWh]
ne_thermal_unit_om_cost = [
    464.64,
    464.64,
    455.13,
    464.64,
    834.35,
    509.86,
    509.86,
    464.64,
    464.64,
    185.09,
    492.29,
    464.64,
    464.64,
    188.15,
    82.34,
    329.37,
    329.37,
    464.64,
    464.64,
    464.64,
    317.19,
    464.64,
    464.64,
    678.03,
    559.39,
    611.57,
    611.56,
    204.43,
    325.67,
    678.03,
    329.2,
    70.16,
    287.83,
]
@assert length(ne_thermal_unit_maximum_generation) == ne_number_of_thermal_units
@assert length(ne_thermal_unit_minimum_generation) == ne_number_of_thermal_units
@assert length(ne_thermal_unit_om_cost) == ne_number_of_thermal_units

# N
n_number_of_thermal_units = 2
# Maximum generation in [MW]
n_thermal_unit_maximum_generation = [0.23074, 0.23074]
# Minimum generation in [MW]
n_thermal_unit_minimum_generation = [0, 0]
# O&M cost in [$/MWh]
n_thermal_unit_om_cost = [329.56, 329.56]
@assert length(n_thermal_unit_maximum_generation) == n_number_of_thermal_units
@assert length(n_thermal_unit_minimum_generation) == n_number_of_thermal_units
@assert length(n_thermal_unit_om_cost) == n_number_of_thermal_units

# All plants
number_of_thermal_units =
    [se_number_of_thermal_units, s_number_of_thermal_units, ne_number_of_thermal_units, n_number_of_thermal_units]
thermal_unit_maximum_generation = [
    se_thermal_unit_maximum_generation,
    s_thermal_unit_maximum_generation,
    ne_thermal_unit_maximum_generation,
    n_thermal_unit_maximum_generation,
]
thermal_unit_minimum_generation = [
    se_thermal_unit_minimum_generation,
    s_thermal_unit_minimum_generation,
    ne_thermal_unit_minimum_generation,
    n_thermal_unit_minimum_generation,
]
thermal_unit_om_cost =
    [se_thermal_unit_om_cost, s_thermal_unit_om_cost, ne_thermal_unit_om_cost, n_thermal_unit_om_cost]
for (bus_idx, bus_number_of_thermal_units) in enumerate(number_of_thermal_units)
    for t in 1:bus_number_of_thermal_units
        IARA.add_thermal_unit!(db;
            label = "ter_" * bus_labels[bus_idx] * "_$t",
            parameters = DataFrame(;
                date_time = [DateTime(0)],
                existing = [Int(IARA.ThermalUnit_Existence.EXISTS)],
                min_generation = [thermal_unit_minimum_generation[bus_idx][t]],
                max_generation = [thermal_unit_maximum_generation[bus_idx][t]],
                om_cost = [thermal_unit_om_cost[bus_idx][t]],
            ),
            bus_id = bus_idx,
        )
    end
end

# Demand
# --------------------
# Data
# Monthly demand in MW
se_monthly_demand = [63.215, 64.738, 65.464, 64.485, 63.364, 63.008, 63.162, 64.096, 64.356, 64.654, 63.938, 62.825]
s_monthly_demand = [16.239, 16.574, 16.674, 15.942, 15.479, 15.481, 15.354, 15.349, 15.162, 15.299, 15.494, 15.690]
ne_monthly_demand = [15.015, 14.838, 14.899, 14.707, 14.429, 14.068, 14.107, 14.406, 14.826, 15.186, 15.283, 15.158]
n_monthly_demand = [9.038, 9.117, 9.036, 9.106, 9.229, 9.262, 9.204, 9.406, 9.504, 9.465, 9.543, 9.307]
im_monthly_demand = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
monthly_demands = [se_monthly_demand, s_monthly_demand, ne_monthly_demand, n_monthly_demand, im_monthly_demand] * 0.9
max_demand = maximum(se_monthly_demand)
# Build the demand matrix
demand = zeros(number_of_buses, number_of_subperiods, number_of_scenarios, number_of_periods)
for period in 1:number_of_periods
    for bus in 1:number_of_buses
        demand[bus, :, :, period] .= monthly_demands[bus][period] / max_demand
    end
end

# One demand per bus, named after the bus
for (bus_idx, label) in enumerate(bus_labels)
    IARA.add_demand_unit!(db;
        label = "dem_$label",
        demand_unit_type = IARA.DemandUnit_DemandType.INELASTIC,
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
        ),
        max_shift_up = 0.0,
        max_shift_down = 0.0,
        curtailment_cost = 0.0,
        max_curtailment = 0.0,
        bus_id = bus_idx,
        max_demand = max_demand,
    )
end

# DC lines
# --------------------
number_of_dc_lines = 10
# Capacity in [MW]
dc_line_capacity_to = [10.25681, 1.39, 0, 0, 0, 0, 5.56, 0, 3.10804, 138.99861]
# Capacity in [MW]
dc_line_capacity_from = [7.81875, 0.834, 0, 0, 0, 0, 4.38406, 0, 5.49189, 4.24367]
dc_line_bus_from = [1, 1, 1, 2, 2, 3, 1, 2, 3, 4]
dc_line_bus_to = [2, 3, 4, 3, 4, 4, 5, 5, 5, 5]
@assert length(dc_line_capacity_to) == number_of_dc_lines
@assert length(dc_line_capacity_from) == number_of_dc_lines
@assert length(dc_line_bus_from) == number_of_dc_lines
@assert length(dc_line_bus_to) == number_of_dc_lines

for d in 1:number_of_dc_lines
    IARA.add_dc_line!(db;
        label = "$(dc_line_bus_from[d])->$(dc_line_bus_to[d])",
        parameters = DataFrame(;
            date_time = [DateTime(0)],
            existing = Int(IARA.DCLine_Existence.EXISTS),
            capacity_to = dc_line_capacity_to[d],
            capacity_from = dc_line_capacity_from[d],
        ),
        bus_from = dc_line_bus_from[d],
        bus_to = dc_line_bus_to[d],
    )
end

# =====================================================
# Create and link CSV files
# =====================================================

# Inflow
# --------------------

iid_inflow = build_iid_inflow(PATH;
    number_of_subperiods = number_of_subperiods,
    number_of_samples = number_of_scenarios,
    number_of_seasons = number_of_nodes,
    subperiod_duration_in_hours = subperiod_duration_in_hours,
    expected_number_of_repeats = expected_number_of_repeats_per_node,
)

# Write to file
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    iid_inflow;
    dimensions = ["season", "sample", "subperiod"],
    labels = ["hyd_$(bus_labels[h])" for h in 1:number_of_hydro_units],
    time_dimension = "season",
    dimension_size = [number_of_nodes, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)
IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow_ex_ante = "inflow",
)

# Demand
# --------------------

# Write to file
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["season", "sample", "subperiod"],
    labels = ["dem_$label" for label in bus_labels],
    time_dimension = "season",
    dimension_size = [number_of_nodes, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)
IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demand",
)

IARA.close_study!(db)
