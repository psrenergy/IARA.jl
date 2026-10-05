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

module TestCase23RenewablesCase

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

number_of_periods = 6

for period in 1:number_of_periods
    IARA.single_period_heuristic_bid(
        PATH;
        plot_outputs = false,
        delete_output_folder_before_execution = true,
        period = period,
        plot_ui_outputs = true,
        output_path = "outputs/heuristic_bid_$period",
    )

    heuristic_bid_path = joinpath(PATH, "outputs/heuristic_bid_$period")

    for extension in ["csv", "toml"]
        cp(
            joinpath(heuristic_bid_path, "bidding_group_energy_bid_period_$period.$extension"),
            joinpath(PATH, "bidding_group_energy_bid.$extension");
            force = true,
        )

        cp(
            joinpath(PATH, "bidding_group_energy_bid.$extension"),
            joinpath(PATH, "bidding_group_no_markup_energy_bid_period_$period.$extension");
            force = true,
        )

        cp(
            joinpath(heuristic_bid_path, "bidding_group_price_bid_period_$period.$extension"),
            joinpath(PATH, "bidding_group_price_bid.$extension");
            force = true,
        )

        cp(
            joinpath(heuristic_bid_path, "bidding_group_no_markup_price_bid_period_$period.$extension"),
            joinpath(PATH, "bidding_group_no_markup_price_bid_period_$period.$extension");
            force = true,
        )
    end

    IARA.single_period_market_clearing(
        PATH;
        plot_outputs = false,
        delete_output_folder_before_execution = true,
        period = period,
        plot_ui_outputs = true,
        output_path = "outputs/market_clearing_$period",
    )

    # Carry the physical state over to the next period. The last period has no
    # successor, so nothing needs to be copied
    if period < number_of_periods
        cp(
            joinpath(
                PATH,
                "outputs/market_clearing_$period",
                "EX_POST_PHYSICAL_period_$(period)_scenario_1.json",
            ),
            joinpath(PATH, "EX_POST_PHYSICAL_period_$(period)_scenario_1.json");
            force = true,
        )
    end
end

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH)
end

end
