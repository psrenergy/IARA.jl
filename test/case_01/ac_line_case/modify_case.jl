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

# Add a branch closing a loop
IARA.add_branch!(db;
    label = "ac_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.Branch_Existence.EXISTS)],
        capacity = [15.0],
        reactance = [0.4],
    ),
    bus_from = "bus_2",
    bus_to = "bus_3",
)

# Avoid degeneracy among blocks
renewable_generation[1, 1, 1, 1] -= 2.0 / 4.0
renewable_generation[1, 1, 2, 1] -= 1.0 / 4.0
renewable_generation[1, 1, 1, 2] -= 2.0 / 4.0
renewable_generation[1, 1, 2, 2] -= 1.0 / 4.0
renewable_generation[1, 2, 1, 3] -= 2.0 / 4.0
renewable_generation[1, 2, 2, 3] -= 1.0 / 4.0

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    renewable_generation;
    dimensions = ["stage", "scenario", "block"],
    labels = ["gnd_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01",
    unit = "p.u.",
)

IARA.close_study!(db)
