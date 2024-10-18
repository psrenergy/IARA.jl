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

update_configuration!(db;
    use_binary_variables = 1,
)

add_thermal_plant!(db;
    label = "ter_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        startup_cost = [0.1] * 1e3,
        min_generation = [1.0],
        max_generation = [5.0],
        om_cost = [4.0],
    ),
    has_commitment = 1,
    max_startups = 2,
    max_shutdowns = 2,
    shutdown_cost = 0.1 * 1e3,
    commitment_initial_condition = 0,
    bus_id = "bus_1",
)

add_thermal_plant!(db;
    label = "ter_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        startup_cost = [0.1] * 1e3,
        min_generation = [1.0],
        max_generation = [5.0],
        om_cost = [10.0],
    ),
    has_commitment = 1,
    max_startups = 2,
    max_shutdowns = 2,
    shutdown_cost = 0.1 * 1e3,
    commitment_initial_condition = 1,
    bus_id = "bus_1",
)

demand[:, 1, end, :] .+= 5.0 * MW_to_GWh
write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

inflow[:, :, 3, end] .+= 0.5
write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["stage", "scenario", "block"],
    labels = ["hyd_1_gauging_station"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

close_study!(db)
