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

IARA.update_configuration!(db;
    hydro_spillage_cost = 1e-3,
)

IARA.add_hydro_unit!(
    db;
    label = "hyd_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.HydroUnit_Existence.EXISTS)],
        min_volume = [0.0],
        max_generation = [3.5],
        production_factor = [1.5],
        max_turbining = [3.5],
        max_volume = [0.0],
        om_cost = [0.0],
    ),
    initial_volume = 0.0,
    bus_id = "bus_2",
)

IARA.set_hydro_turbine_to!(
    db,
    "hyd_1",
    "hyd_2",
)

IARA.set_hydro_spill_to!(
    db,
    "hyd_1",
    "hyd_2",
)

new_inflow = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods)
new_inflow[1, :, :, :] .= inflow[1, :, :, :]

IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    new_inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hyd_1_gauging_station", "hyd_2_gauging_station"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

IARA.update_hydro_unit!(
    db,
    "hyd_2";
    operation_type = IARA.HydroUnit_OperationType.RUN_OF_RIVER,
)

IARA.close_study!(db)
