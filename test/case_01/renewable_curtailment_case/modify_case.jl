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

IARA.delete_element!(db,
    "RenewableUnit",
    "gnd_1",
)

IARA.add_renewable_unit!(db;
    label = "gnd_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.RenewableUnit_Existence.EXISTS)],
        max_generation = [8.0],
        om_cost = [0.0],
        curtailment_cost = [0.1],
    ),
    technology_type = 1,
    bus_id = "bus_2",
)

new_renewable_generation = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
new_renewable_generation .= renewable_generation / 2
new_renewable_generation[1, :, 4, :] .= 1.0
IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    new_renewable_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["gnd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.update_hydro_unit!(db, "hyd_1"; initial_volume = 0.0)

new_inflow = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
new_inflow[1, :, 1, :] .= 1.5
new_inflow[1, :, 2, :] .= 2.5
new_inflow[1, :, 3, :] .= 3.5
new_inflow[1, :, 4, :] .= 0.0

IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    new_inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hyd_1_gauging_station"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

IARA.close_study!(db)
