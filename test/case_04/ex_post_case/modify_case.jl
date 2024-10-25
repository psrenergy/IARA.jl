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

# Update base case elements
IARA.update_configuration!(db;
    number_of_subscenarios,
)

# Create and link CSV files
# -------------------------
# Demand
mv(joinpath(PATH, "demand.csv"), joinpath(PATH, "demand_ex_ante.csv"); force = true)
mv(joinpath(PATH, "demand.toml"), joinpath(PATH, "demand_ex_ante.toml"); force = true)

demand_ex_post = zeros(1, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
demand_ex_post[:, :, 1, :, :] = demand .- (0.1 / 1e3)
demand_ex_post[:, :, 2, :, :] = demand .+ (0.1 / 1e3)
IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    demand_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand = "demand_ex_ante",
)

IARA.close_study!(db)
