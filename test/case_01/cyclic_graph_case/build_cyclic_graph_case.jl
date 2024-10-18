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

new_block_duration = 30.0

update_configuration!(db;
    policy_graph_type = IARA.Configurations_PolicyGraphType.CYCLIC,
    yearly_discount_rate = 0.05,
    number_of_nodes = number_of_stages,
    block_duration_in_hours = [new_block_duration for _ in 1:number_of_blocks],
)

update_hydro_plant!(
    db,
    "hyd_1";
    initial_volume = 12.0 * m3_per_second_to_hm3 * (new_block_duration / block_duration_in_hours),
)
update_hydro_plant_time_series_parameter!(
    db,
    "hyd_1",
    "max_volume",
    30.0 * m3_per_second_to_hm3 * (new_block_duration / block_duration_in_hours);
    date_time = DateTime(0),
)

demand = demand * new_block_duration / block_duration_in_hours

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

close_study!(db)
