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

plant_time_series_parameters_1 = DataFrame(;
    date_time = [DateTime("2020-01-01T00:00:00"), DateTime("2020-03-01T00:00:00")],
    existing = [Int(IARA.RenewableUnit_Existence.EXISTS), Int(IARA.RenewableUnit_Existence.EXISTS)],
    max_generation = [4.0, 2.0],
    curtailment_cost = [0.1, 0.2] * 1e3,
    om_cost = [0.0, 0.0],
)

plant_time_series_parameters_2 = DataFrame(;
    date_time = [DateTime("2020-01-01T00:00:00"), DateTime("2020-03-01T00:00:00")],
    existing = [Int(IARA.RenewableUnit_Existence.DOES_NOT_EXIST), Int(IARA.RenewableUnit_Existence.EXISTS)],
    om_cost = [0.0, 0.0],
    max_generation = [0.0, 2.0],
    curtailment_cost = [0.0, 0.2] * 1e3,
)

IARA.add_renewable_unit!(db;
    label = "gnd_1",
    technology_type = 1,
    bus_id = "bus_2",
    parameters = plant_time_series_parameters_1,
)
IARA.add_renewable_unit!(db;
    label = "gnd_2",
    technology_type = 1,
    bus_id = "bus_2",
    parameters = plant_time_series_parameters_2,
)

renewable_generation = cat(renewable_generation, renewable_generation; dims = 1)
IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    renewable_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["gnd_1", "gnd_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.close_study!(db)
