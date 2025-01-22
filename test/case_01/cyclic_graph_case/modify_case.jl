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

new_subperiod_duration = 30.0

IARA.update_configuration!(db;
    policy_graph_type = IARA.Configurations_PolicyGraphType.CYCLIC_WITH_NULL_ROOT,
    cycle_discount_rate = 0.05,
    cycle_duration_in_hours = 180.0,
    number_of_nodes = number_of_periods,
    subperiod_duration_in_hours = [new_subperiod_duration for _ in 1:number_of_subperiods],
)

IARA.update_hydro_unit!(
    db,
    "hyd_1";
    initial_volume = 12.0 * m3_per_second_to_hm3 * (new_subperiod_duration / subperiod_duration_in_hours),
)
IARA.update_hydro_unit_time_series_parameter!(
    db,
    "hyd_1",
    "max_volume",
    30.0 * m3_per_second_to_hm3 * (new_subperiod_duration / subperiod_duration_in_hours);
    date_time = DateTime(0),
)

IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.close_study!(db)
