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

add_reserve!(db;
    label = "res_up",
    direction = IARA.Reserve_Direction.UP,
    violation_cost = 1000.0,
    hydroplant_id = ["hyd_1"],
    battery_id = ["bat_1"],
    constraint_type = IARA.Reserve_ConstraintType.EQUALITY,
)

add_reserve!(db;
    label = "res_down",
    constraint_type = IARA.Reserve_ConstraintType.EQUALITY,
    direction = IARA.Reserve_Direction.DOWN,
    violation_cost = 900.0,
    thermalplant_id = ["ter_1"],
)

reserve_requirement = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages)
reserve_requirement[1, :, :, :] .= 0.1
reserve_requirement[2, :, :, :] .= 3.0
# hydro spillage
reserve_requirement[1, 1, 1, 2] = 1.0
reserve_requirement[1, 1, 1, 3] = 2.0
reserve_requirement[1, 2, 4, 3] = 0.0

write_timeseries_file(
    joinpath(PATH, "reserve_requirement"),
    reserve_requirement;
    dimensions = ["stage", "scenario", "block"],
    labels = ["res_up", "res_down"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020",
    unit = "MW",
)

link_time_series_to_file(
    db,
    "Reserve";
    reserve_requirement = "reserve_requirement",
)

close_study!(db)
