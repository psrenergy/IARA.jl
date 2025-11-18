#############################################################################
#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

module TestCase21HydroCase

using Test
using IARA

const PATH = @__DIR__

db = nothing
try
    include("../base_case/build_case.jl")
    include("modify_case.jl")
finally
    if db !== nothing
        IARA.close_study!(db)
    end
end

# Setup
IARA.train_min_cost(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    output_path = "outputs/mincost",
)
mv(joinpath(PATH, "outputs/mincost", "cuts.json"), joinpath(PATH, "cuts.json"); force = true)

IARA.InterfaceCalls.interface_call(
    PATH;
    delete_output_folder_before_execution = true,
    output_path = "outputs/interface_call",
)

# Period 1
IARA.single_period_heuristic_bid(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 1,
    plot_ui_outputs = true,
    output_path = "outputs/heuristic_bid_1",
)
IARA.single_period_market_clearing(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 1,
    plot_ui_outputs = true,
    output_path = "outputs/market_clearing_1",
)

# Inter-period
mv(
    joinpath(PATH, "outputs/market_clearing_1", "EX_POST_PHYSICAL_period_1_scenario_1.json"),
    joinpath(PATH, "EX_POST_PHYSICAL_period_1_scenario_1.json");
    force = true,
)
mv(
    joinpath(PATH, "outputs/market_clearing_1", "virtual_reservoir_energy_account_period_1_scenario_1.json"),
    joinpath(PATH, "virtual_reservoir_energy_account_period_1_scenario_1.json");
    force = true,
)
mv(
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_1.csv"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_2.csv");
    force = true,
)
mv(
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_1.toml"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_2.toml");
    force = true,
)
mv(
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_1.csv"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_2.csv");
    force = true,
)
mv(
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_1.toml"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_2.toml");
    force = true,
)
mv(
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_1.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_2.csv");
    force = true,
)
mv(
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_1.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_2.toml");
    force = true,
)
mv(
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_1.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_2.csv");
    force = true,
)
mv(
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_1.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_2.toml");
    force = true,
)

# Period 2
IARA.single_period_heuristic_bid(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 2,
    plot_ui_outputs = true,
    output_path = "outputs/heuristic_bid_2",
)
IARA.single_period_market_clearing(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 2,
    plot_ui_outputs = true,
    output_path = "outputs/market_clearing_2",
)

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH)
end

end
