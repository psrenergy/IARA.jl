#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

using Dates
using DataFrames

IARA.update_configuration!(
    db;
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
)

max_generation = 50.0

IARA.add_renewable_unit!(db;
    label = "Renovavel 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [max_generation],
        om_cost = [0.0],
        curtailment_cost = [0.1],
    ),
    technology_type = 1,
    bus_id = "Sistema",
)

renewable_generation_ex_post =
    zeros(1, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
renewable_generation_ex_post[:, :, 1, :, :] .= 15 / max_generation
renewable_generation_ex_post[:, :, 2, :, :] .= 25 / max_generation
renewable_generation_ex_post[:, :, 3, :, :] .= 35 / max_generation
renewable_generation_ex_post[:, :, 4, :, :] .= 45 / max_generation

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation_ex_post"),
    renewable_generation_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Renovavel 1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2024-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_post = "renewable_generation_ex_post",
)
