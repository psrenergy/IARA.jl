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

subperiod_duration_in_hours = 6.0
expected_number_of_repeats_per_node = 5.0

IARA.update_configuration!(db;
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    expected_number_of_repeats_per_node = [expected_number_of_repeats_per_node for _ in 1:number_of_nodes]
)

iid_inflow = build_iid_inflow(PATH;
    number_of_subperiods = number_of_subperiods,
    number_of_samples = number_of_scenarios,
    number_of_seasons = number_of_nodes,
    subperiod_duration_in_hours = subperiod_duration_in_hours,
    expected_number_of_repeats = mean(expected_number_of_repeats_per_node),
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

IARA.close_study!(db)
