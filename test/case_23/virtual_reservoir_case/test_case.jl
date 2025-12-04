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

module TestCase23VirtualReservoirCase

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
cp(joinpath(PATH, "outputs/mincost", "cuts.json"), joinpath(PATH, "cuts.json"); force = true)

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

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "bidding_group_energy_bid_period_1.csv"),
    joinpath(PATH, "bidding_group_energy_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "bidding_group_energy_bid_period_1.toml"),
    joinpath(PATH, "bidding_group_energy_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "bidding_group_energy_bid.csv"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_1.csv");
    force = true,
)

cp(
    joinpath(PATH, "bidding_group_energy_bid.toml"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_1.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "bidding_group_price_bid_period_1.csv"),
    joinpath(PATH, "bidding_group_price_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "bidding_group_price_bid_period_1.toml"),
    joinpath(PATH, "bidding_group_price_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "bidding_group_no_markup_price_bid_period_1.csv"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_1.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "bidding_group_no_markup_price_bid_period_1.toml"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_1.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "virtual_reservoir_energy_bid_period_1.csv"),
    joinpath(PATH, "virtual_reservoir_energy_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "virtual_reservoir_energy_bid_period_1.toml"),
    joinpath(PATH, "virtual_reservoir_energy_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "virtual_reservoir_price_bid_period_1.csv"),
    joinpath(PATH, "virtual_reservoir_price_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "virtual_reservoir_price_bid_period_1.toml"),
    joinpath(PATH, "virtual_reservoir_price_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "virtual_reservoir_no_markup_price_bid_period_1.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_1.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_1", "virtual_reservoir_no_markup_price_bid_period_1.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_1.toml");
    force = true,
)

cp(
    joinpath(PATH, "virtual_reservoir_energy_bid.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_1.csv");
    force = true,
)

cp(
    joinpath(PATH, "virtual_reservoir_energy_bid.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_1.toml");
    force = true,
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
cp(
    joinpath(PATH, "outputs/market_clearing_1", "EX_POST_PHYSICAL_period_1_scenario_1.json"),
    joinpath(PATH, "EX_POST_PHYSICAL_period_1_scenario_1.json");
    force = true,
)
cp(
    joinpath(PATH, "outputs/market_clearing_1", "virtual_reservoir_energy_account_period_1_scenario_1.json"),
    joinpath(PATH, "virtual_reservoir_energy_account_period_1_scenario_1.json");
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

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "bidding_group_energy_bid_period_2.csv"),
    joinpath(PATH, "bidding_group_energy_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "bidding_group_energy_bid_period_2.toml"),
    joinpath(PATH, "bidding_group_energy_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "bidding_group_energy_bid.csv"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_2.csv");
    force = true,
)

cp(
    joinpath(PATH, "bidding_group_energy_bid.toml"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_2.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "bidding_group_price_bid_period_2.csv"),
    joinpath(PATH, "bidding_group_price_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "bidding_group_price_bid_period_2.toml"),
    joinpath(PATH, "bidding_group_price_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "bidding_group_no_markup_price_bid_period_2.csv"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_2.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "bidding_group_no_markup_price_bid_period_2.toml"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_2.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "virtual_reservoir_energy_bid_period_2.csv"),
    joinpath(PATH, "virtual_reservoir_energy_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "virtual_reservoir_energy_bid_period_2.toml"),
    joinpath(PATH, "virtual_reservoir_energy_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "virtual_reservoir_price_bid_period_2.csv"),
    joinpath(PATH, "virtual_reservoir_price_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "virtual_reservoir_price_bid_period_2.toml"),
    joinpath(PATH, "virtual_reservoir_price_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "virtual_reservoir_no_markup_price_bid_period_2.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_2.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_2", "virtual_reservoir_no_markup_price_bid_period_2.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_2.toml");
    force = true,
)

cp(
    joinpath(PATH, "virtual_reservoir_energy_bid.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_2.csv");
    force = true,
)

cp(
    joinpath(PATH, "virtual_reservoir_energy_bid.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_2.toml");
    force = true,
)

IARA.single_period_market_clearing(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 2,
    plot_ui_outputs = true,
    output_path = "outputs/market_clearing_2",
)

# Inter-period
cp(
    joinpath(PATH, "outputs/market_clearing_2", "EX_POST_PHYSICAL_period_2_scenario_1.json"),
    joinpath(PATH, "EX_POST_PHYSICAL_period_2_scenario_1.json");
    force = true,
)
cp(
    joinpath(PATH, "outputs/market_clearing_2", "virtual_reservoir_energy_account_period_2_scenario_1.json"),
    joinpath(PATH, "virtual_reservoir_energy_account_period_2_scenario_1.json");
    force = true,
)

# Period 3
IARA.single_period_heuristic_bid(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 3,
    plot_ui_outputs = true,
    output_path = "outputs/heuristic_bid_3",
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "bidding_group_energy_bid_period_3.csv"),
    joinpath(PATH, "bidding_group_energy_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "bidding_group_energy_bid_period_3.toml"),
    joinpath(PATH, "bidding_group_energy_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "bidding_group_energy_bid.csv"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_3.csv");
    force = true,
)

cp(
    joinpath(PATH, "bidding_group_energy_bid.toml"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_3.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "bidding_group_price_bid_period_3.csv"),
    joinpath(PATH, "bidding_group_price_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "bidding_group_price_bid_period_3.toml"),
    joinpath(PATH, "bidding_group_price_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "bidding_group_no_markup_price_bid_period_3.csv"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_3.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "bidding_group_no_markup_price_bid_period_3.toml"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_3.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "virtual_reservoir_energy_bid_period_3.csv"),
    joinpath(PATH, "virtual_reservoir_energy_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "virtual_reservoir_energy_bid_period_3.toml"),
    joinpath(PATH, "virtual_reservoir_energy_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "virtual_reservoir_price_bid_period_3.csv"),
    joinpath(PATH, "virtual_reservoir_price_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "virtual_reservoir_price_bid_period_3.toml"),
    joinpath(PATH, "virtual_reservoir_price_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "virtual_reservoir_no_markup_price_bid_period_3.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_3.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_3", "virtual_reservoir_no_markup_price_bid_period_3.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_3.toml");
    force = true,
)

cp(
    joinpath(PATH, "virtual_reservoir_energy_bid.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_3.csv");
    force = true,
)

cp(
    joinpath(PATH, "virtual_reservoir_energy_bid.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_3.toml");
    force = true,
)

IARA.single_period_market_clearing(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 3,
    plot_ui_outputs = true,
    output_path = "outputs/market_clearing_3",
)

# Inter-period
cp(
    joinpath(PATH, "outputs/market_clearing_3", "EX_POST_PHYSICAL_period_3_scenario_1.json"),
    joinpath(PATH, "EX_POST_PHYSICAL_period_3_scenario_1.json");
    force = true,
)
cp(
    joinpath(PATH, "outputs/market_clearing_3", "virtual_reservoir_energy_account_period_3_scenario_1.json"),
    joinpath(PATH, "virtual_reservoir_energy_account_period_3_scenario_1.json");
    force = true,
)

# Period 4
IARA.single_period_heuristic_bid(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 4,
    plot_ui_outputs = true,
    output_path = "outputs/heuristic_bid_4",
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "bidding_group_energy_bid_period_4.csv"),
    joinpath(PATH, "bidding_group_energy_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "bidding_group_energy_bid_period_4.toml"),
    joinpath(PATH, "bidding_group_energy_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "bidding_group_energy_bid.csv"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_4.csv");
    force = true,
)

cp(
    joinpath(PATH, "bidding_group_energy_bid.toml"),
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_4.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "bidding_group_price_bid_period_4.csv"),
    joinpath(PATH, "bidding_group_price_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "bidding_group_price_bid_period_4.toml"),
    joinpath(PATH, "bidding_group_price_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "bidding_group_no_markup_price_bid_period_4.csv"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_4.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "bidding_group_no_markup_price_bid_period_4.toml"),
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_4.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "virtual_reservoir_energy_bid_period_4.csv"),
    joinpath(PATH, "virtual_reservoir_energy_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "virtual_reservoir_energy_bid_period_4.toml"),
    joinpath(PATH, "virtual_reservoir_energy_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "virtual_reservoir_price_bid_period_4.csv"),
    joinpath(PATH, "virtual_reservoir_price_bid.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "virtual_reservoir_price_bid_period_4.toml"),
    joinpath(PATH, "virtual_reservoir_price_bid.toml");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "virtual_reservoir_no_markup_price_bid_period_4.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_4.csv");
    force = true,
)

cp(
    joinpath(PATH, "outputs/heuristic_bid_4", "virtual_reservoir_no_markup_price_bid_period_4.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_price_bid_period_4.toml");
    force = true,
)

cp(
    joinpath(PATH, "virtual_reservoir_energy_bid.csv"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_4.csv");
    force = true,
)

cp(
    joinpath(PATH, "virtual_reservoir_energy_bid.toml"),
    joinpath(PATH, "virtual_reservoir_no_markup_energy_bid_period_4.toml");
    force = true,
)

IARA.single_period_market_clearing(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 4,
    plot_ui_outputs = true,
    output_path = "outputs/market_clearing_4",
)

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH)
end

end
