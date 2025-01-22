#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = IARA.load_study(PATH; read_only = false)

# Add a elastic demand
IARA.add_demand_unit!(db;
    label = "dem_2",
    demand_unit_type = IARA.DemandUnit_DemandType.ELASTIC,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
    ),
    bus_id = "bus_2",
    max_demand = max_demand,
)

# Modify the demand timeseries to include elastic demand
new_demand = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods)
new_demand[1, :, :, :] .= demand[1, :, :, :]
new_demand[2, :, 1, :] .= 1.5 / max_demand
new_demand[2, :, 2, :] .= 1.0 / max_demand
new_demand[2, :, [3, 4], 1] .= 1.0 / max_demand

IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    new_demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1", "dem_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01",
    unit = "p.u.",
)

# Create the demand price timeseries
demand_price = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
demand_price[1, 1, :, :] .= 0.3
demand_price[1, 2, :, :] .= 1.3

IARA.write_timeseries_file(
    joinpath(PATH, "demand_price"),
    demand_price;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01",
    unit = "\$/MWh",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    elastic_demand_price = "demand_price",
)

# Modify the renewable timeseries to avoid degeneracy
IARA.update_renewable_unit_time_series!(db, "gnd_1"; max_generation = 4.5)

new_renewable_generation = renewable_generation * 4.0 / 4.5
new_renewable_generation[1, 2, 1, 2] += 0.5 / 4.5
new_renewable_generation[1, 2, 1, 1] -= 0.5 / 4.5
new_renewable_generation[1, 2, 1, 3] += 0.5 / 4.5

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    new_renewable_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["gnd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01",
    unit = "p.u.",
)

IARA.close_study!(db)
