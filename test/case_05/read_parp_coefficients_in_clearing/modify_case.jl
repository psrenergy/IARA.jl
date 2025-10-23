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

number_of_subscenarios = 2

IARA.update_configuration!(db;
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    number_of_subscenarios = number_of_subscenarios,
)

inflow_noise_ex_post = zeros(1, number_of_subscenarios, number_of_scenarios, number_of_periods)
inflow_noise_ex_post[:, 1, :, :] = inflow_noise * 1.2
inflow_noise_ex_post[:, 2, :, :] = inflow_noise * 0.8

IARA.write_timeseries_file(
    joinpath(PATH, "parp", "inflow_noise_ex_post"),
    inflow_noise_ex_post;
    dimensions = ["period", "scenario", "subscenario"],
    labels = ["gs_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

IARA.link_time_series_to_file(
    db,
    "GaugingStation";
    inflow_noise_ex_post = "inflow_noise_ex_post",
)

IARA.close_study!(db)
