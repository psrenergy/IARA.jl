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
number_of_scenarios = 2
number_of_subperiods = 4
subperiod_duration_in_hours = 1.0
MW_to_GWh = subperiod_duration_in_hours * 1e-3

db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    initial_date_time = "2024-01-01",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    yearly_discount_rate = 0.1,
    demand_deficit_cost = 0.5,
)

IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

IARA.add_demand_unit!(
    db;
    label = "flex_dem_1",
    demand_unit_type = IARA.Demand_Unit_DemandType.FLEXIBLE,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.Demand_Unit_Existence.EXISTS)],
    ),
    max_shift_up = 1.0,
    max_shift_down = 1.0,
    curtailment_cost = 0.25,
    max_curtailment = 0.02,
    bus_id = "bus_1",
)

demand =
    MW_to_GWh *
    [b + t / 4 + s for d in 1:1, b in 1:number_of_subperiods, s in 1:number_of_scenarios, t in 1:number_of_periods]

IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["flex_dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "GWh",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand = "demand",
)

demand_window = zeros(Float64, 1, number_of_subperiods, number_of_periods)
demand_window[1, [1, 2], :] .= 1.0
demand_window[1, [3, 4], :] .= 2.0

IARA.write_timeseries_file(
    joinpath(PATH, "demand_window"),
    demand_window;
    dimensions = ["period", "subperiod"],
    labels = ["flex_dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "-",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_window = "demand_window",
)

IARA.add_thermal_unit!(
    db;
    label = "thermal_1",
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        max_generation = 6.0,
        om_cost = 0.0,
    ),
)

IARA.close_study!(db)
