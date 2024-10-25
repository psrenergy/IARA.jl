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
    use_binary_variables = IARA.Configurations_BinaryVariableUsage.USE,
)

IARA.add_thermal_unit!(db;
    label = "ter_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.ThermalUnit_Existence.EXISTS)],
        startup_cost = [0.1] * 1e3,
        min_generation = [1.0],
        max_generation = [5.0],
        om_cost = [4.0],
    ),
    has_commitment = Int(IARA.ThermalUnit_HasCommitment.HAS_COMMITMENT),
    max_startups = 2,
    max_shutdowns = 2,
    shutdown_cost = 0.1 * 1e3,
    commitment_initial_condition = Int(IARA.ThermalUnit_CommitmentInitialCondition.OFF),
    bus_id = "bus_1",
)

IARA.add_thermal_unit!(db;
    label = "ter_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.ThermalUnit_Existence.EXISTS)],
        startup_cost = [0.1] * 1e3,
        min_generation = [1.0],
        max_generation = [5.0],
        om_cost = [10.0],
    ),
    has_commitment = Int(IARA.ThermalUnit_HasCommitment.HAS_COMMITMENT),
    max_startups = 2,
    max_shutdowns = 2,
    shutdown_cost = 0.1 * 1e3,
    commitment_initial_condition = Int(IARA.ThermalUnit_CommitmentInitialCondition.ON),
    bus_id = "bus_1",
)

demand[:, 1, end, :] .+= 5.0 * MW_to_GWh
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

inflow[:, :, 3, end] .+= 0.5
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hyd_1_gauging_station"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

IARA.close_study!(db)
