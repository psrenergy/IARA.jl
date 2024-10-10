#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = load_study(PATH; read_only = false)

# Add a elastic demand
add_demand!(db;
    label = "dem_2",
    demand_type = IARA.Demand_DemandType.ELASTIC,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "bus_2",
)

# Modify the demand timeseries to include elastic demand
new_demand = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages)
new_demand[1, :, :, :] .= demand[1, :, :, :]
new_demand[2, :, 1, :] .= 1.5 * MW_to_GWh
new_demand[2, :, 2, :] .= 1.0 * MW_to_GWh
new_demand[2, :, [3, 4], 1] .= 1.0 * MW_to_GWh

write_timeseries_file(
    joinpath(PATH, "demand"),
    new_demand;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_1", "dem_2"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01",
    unit = "GWh",
)

# Create the demand price timeseries
demand_price = zeros(1, number_of_blocks, number_of_scenarios, number_of_stages)
demand_price[1, 1, :, :] .= 0.3
demand_price[1, 2, :, :] .= 1.3

write_timeseries_file(
    joinpath(PATH, "demand_price"),
    demand_price;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_2"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01",
    unit = "\$/MWh",
)

link_time_series_to_file(
    db,
    "Demand";
    elastic_demand_price = "demand_price",
)

# Modify the renewable timeseries to avoid degeneracy
update_renewable_plant_time_series!(db, "gnd_1"; max_generation = 4.5)

new_renewable_generation = renewable_generation * 4.0 / 4.5
new_renewable_generation[1, 2, 1, 2] += 0.5 / 4.5
new_renewable_generation[1, 2, 1, 1] -= 0.5 / 4.5
new_renewable_generation[1, 2, 1, 3] += 0.5 / 4.5

write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    new_renewable_generation;
    dimensions = ["stage", "scenario", "block"],
    labels = ["gnd_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01",
    unit = "p.u.",
)

close_study!(db)
