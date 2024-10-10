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

add_battery!(db;
    label = "bat_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        min_storage = [0.0],
        max_storage = [10.0] * 1e3,
        max_capacity = [0.5],
        om_cost = [1.0],
    ),
    initial_storage = 0.0,
    bus_id = "bus_2",
)

# Modify the renewable generation
renewable_generation[:, 1, end, :] .+= 0.25
write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    renewable_generation;
    dimensions = ["stage", "scenario", "block"],
    labels = ["gnd_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

close_study!(db)
