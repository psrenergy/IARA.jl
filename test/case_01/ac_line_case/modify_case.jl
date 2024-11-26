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

# Change the DC line to an AC line

IARA.delete_element!(db, "DCLine", "dc_1")

IARA.add_branch!(db;
    label = "ac_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.Branch_Existence.EXISTS)],
        capacity = [5.5],
        reactance = [0.5],
    ),
    bus_from = "bus_1",
    bus_to = "bus_2",
)

# Move the demand to a new bus

IARA.add_bus!(db; label = "bus_3", zone_id = "zone_1")

IARA.add_branch!(db;
    label = "ac_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.Branch_Existence.EXISTS)],
        capacity = [10.0],
        reactance = [0.2],
    ),
    bus_from = "bus_1",
    bus_to = "bus_3",
)

IARA.update_demand_relation!(db, "dem_1"; collection = "Bus", relation_type = "id", related_label = "bus_3")

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

# Avoid degeneracy among subperiods
renewable_generation[1, 1, 1, 1] -= 2.0 / 4.0
renewable_generation[1, 1, 2, 1] -= 1.0 / 4.0
renewable_generation[1, 1, 1, 2] -= 2.0 / 4.0
renewable_generation[1, 1, 2, 2] -= 1.0 / 4.0
renewable_generation[1, 2, 1, 3] -= 2.0 / 4.0
renewable_generation[1, 2, 2, 3] -= 1.0 / 4.0

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    renewable_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["gnd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01",
    unit = "p.u.",
)

IARA.close_study!(db)
