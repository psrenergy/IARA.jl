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

# Load the database
# ----------------
db = IARA.load_study(PATH; read_only = false)

number_of_subscenarios = 4  # For ex-post scenarios

# Update configuration for ex-post demand
IARA.update_configuration!(db;
    number_of_subscenarios,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    settlement_type = IARA.Configurations_FinancialSettlementType.EX_POST,
)

# Move existing demand file to _ex_ante suffix
if isfile(joinpath(PATH, "demand.csv"))
    mv(joinpath(PATH, "demand.csv"), joinpath(PATH, "demand_ex_ante.csv"); force = true)
    mv(joinpath(PATH, "demand.toml"), joinpath(PATH, "demand_ex_ante.toml"); force = true)
end

# Create demand ex-post scenarios
# ------------------------------
# Load the original demand data
demand_ex_ante = copy(new_demand)

# Create ex-post demand scenarios (add some variability)
demand_ex_post = zeros(
    size(demand_ex_ante, 1),  # number of demand units
    number_of_subperiods,
    number_of_subscenarios,
    number_of_scenarios,
    number_of_periods,
)

# First subscenario: decrease demand by 10%
demand_ex_post[:, :, 1, :, :] = demand_ex_ante * 0.9
# Second subscenario: increase demand by 10%
demand_ex_post[:, :, 2, :, :] = demand_ex_ante * 1.1
# Third subscenario: decrease demand by 20%
demand_ex_post[:, :, 3, :, :] = demand_ex_ante * 0.8
# Fourth subscenario: increase demand by 20%
demand_ex_post[:, :, 4, :, :] = demand_ex_ante * 1.2

# Write the ex-post demand file
IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    demand_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["dem_1", "dem_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subscenarios,
        number_of_subperiods,
    ],
    initial_date = "2020-01-01",
    unit = "p.u.",
)

# Update the time series links to include ex-post data
IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demand_ex_ante",
    demand_ex_post = "demand_ex_post",
)

# Close the database
IARA.close_study!(db)
