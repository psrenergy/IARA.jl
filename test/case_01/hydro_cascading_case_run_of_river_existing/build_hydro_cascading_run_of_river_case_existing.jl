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
    hydro_spillage_cost = 1e-3,
)

add_hydro_plant!(
    db;
    label = "hyd_2",
    parameters = DataFrame(;
        date_time = [DateTime(0), DateTime("2020-03-01T00:00:00")],
        existing = [0, 1],
        min_volume = [0.0, missing],
        max_generation = [3.5, missing],
        production_factor = [1.5, missing],
        max_turbining = [3.5, missing],
        max_volume = [0.1, missing],
        om_cost = [0.0, missing],
    ),
    operation_type = IARA.HydroPlant_OperationType.RUN_OF_RIVER,
    initial_volume = 0.01,
    bus_id = "bus_2",
)

set_hydro_turbine_to!(
    db,
    "hyd_1",
    "hyd_2",
)

set_hydro_spill_to!(
    db,
    "hyd_1",
    "hyd_2",
)

new_inflow = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages)
new_inflow[1, :, :, :] .= inflow[1, :, :, :]

write_timeseries_file(
    joinpath(PATH, "inflow"),
    new_inflow;
    dimensions = ["stage", "scenario", "block"],
    labels = ["hyd_1_gauging_station", "hyd_2_gauging_station"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

close_study!(db)
