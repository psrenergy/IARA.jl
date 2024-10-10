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
    label = "single_thermal_reserve",
    constraint_type = IARA.Reserve_ConstraintType.EQUALITY,
    direction = IARA.Reserve_Direction.UP,
    violation_cost = 700.0 / 1e3,
    thermalplant_id = ["min_downtime_plant"],
)

add_reserve!(db;
    label = "two_thermals_reserve",
    constraint_type = IARA.Reserve_ConstraintType.EQUALITY,
    direction = IARA.Reserve_Direction.UP,
    violation_cost = 750.0 / 1e3,
    thermalplant_id = ["max_uptime_plant", "unconstrained_plant"],
)

reserve_requirement = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages) .+ 1.0
write_timeseries_file(
    joinpath(PATH, "reserve_requirement"),
    reserve_requirement;
    dimensions = ["stage", "scenario", "block"],
    labels = ["single_thermal_reserve", "two_thermals_reserve"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020",
)

link_time_series_to_file(
    db,
    "Reserve";
    reserve_requirement = "reserve_requirement",
)

close_study!(db)
