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
    cycle_discount_rate = 0.0,
    cycle_duration_in_hours = 8760.0,
    demand_deficit_cost = 500.0,
    hydro_spillage_cost = 1e-3,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")
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

IARA.add_hydro_unit!(db;
    label = "hyd_1",
    parameters = DataFrame(;
        date_time = [DateTime(0), DateTime("2020-03-01T00:00:00")],
        existing = [Int(IARA.HydroUnit_Existence.DOES_NOT_EXIST), Int(IARA.HydroUnit_Existence.EXISTS)],
        production_factor = [1.0, missing],
        min_generation = [0.0, missing],
        max_generation = [3.5, missing],
        max_turbining = [3.5, missing],
        min_volume = [0.0, missing],
        max_volume = [0.0, missing],
        min_outflow = [0.0, missing],
        om_cost = [0.0, missing],
    ),
    operation_type = IARA.HydroUnit_OperationType.RUN_OF_RIVER,
    initial_volume = 0.0,
    bus_id = "bus_2",
)

IARA.add_thermal_unit!(db;
    label = "ter_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 1.0,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
)

IARA.add_demand_unit!(db;
    label = "dem_1",
    demand_unit_type = IARA.DemandUnit_DemandType.INELASTIC,
    max_shift_up = 0.0,
    max_shift_down = 0.0,
    curtailment_cost = 0.0,
    max_curtailment = 0.0,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
    ),
    bus_id = "bus_1",
    max_demand = 10.0,
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
    "HydroUnit";
    inflow_ex_ante = "inflow",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demand",
)

IARA.add_hydro_unit!(db;
    label = "hyd_2",
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
)

IARA.add_hydro_unit!(
    db;
    label = "hyd_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.HydroUnit_Existence.EXISTS)],
        min_volume = [0.0],
        max_generation = [3.5],
        production_factor = [1.5],
        max_turbining = [3.5],
        max_volume = [0.0],
        om_cost = [0.0],
    ),
    operation_type = IARA.HydroUnit_OperationType.RUN_OF_RIVER,
    initial_volume = 0.0,
    bus_id = "bus_2",
)

IARA.set_hydro_turbine_to!(
    db,
    "hyd_1",
    "hyd_2",
)

IARA.set_hydro_spill_to!(
    db,
    "hyd_1",
    "hyd_2",
)

IARA.set_hydro_turbine_to!(
    db,
    "hyd_2",
    "hyd_3",
)

IARA.set_hydro_spill_to!(
    db,
    "hyd_2",
    "hyd_3",
)

inflow = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
for scen in 1:number_of_scenarios
    inflow[:, :, scen, :] .+= (scen - 1) / 2
end

new_inflow = zeros(3, number_of_subperiods, number_of_scenarios, number_of_periods)
new_inflow[1, :, :, :] .= inflow[1, :, :, :]

IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    new_inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hyd_1", "hyd_2", "hyd_3"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

IARA.close_study!(db)
