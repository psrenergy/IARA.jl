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

module TestCase07SupplyFunctionEquilibriumBgRiskFactor

using Test
using CSV
using DataFrames
using IARA

const PATH = @__DIR__

db = nothing
try
    include("../base_case/build_case.jl")
    include("../supply_function_equilibrium/modify_case.jl")
    include("../supply_function_equilibrium_with_thermals/modify_case.jl")
    include("../supply_function_equilibrium_only_thermals/modify_case.jl")
    include("modify_case.jl")
finally
    if db !== nothing
        IARA.close_study!(db)
    end
end

IARA.train_min_cost(PATH; plot_outputs = false, delete_output_folder_before_execution = true)
mv(joinpath(PATH, "outputs", "cuts.json"), joinpath(PATH, "cuts.json"); force = true)

IARA.market_clearing(PATH; plot_outputs = false, delete_output_folder_before_execution = true)

# The bids that reach the clearing problem come from the supply function equilibrium, not from the heuristic pass.
# If the equilibrium output were computed and then dropped, these bids would equal the heuristic ones.
@testset "Supply function equilibrium bids reach the clearing problem" begin
    outputs_dir = joinpath(PATH, "outputs")

    # The bid outputs are wide: the first four columns are the dimensions, one column per "bidding group - bus" pair.
    function bid_values(file_name)
        df = CSV.read(joinpath(outputs_dir, file_name), DataFrame)
        dimensions = ["period", "scenario", "subperiod", "bid_segment"]
        values = Float64[]
        for column in names(df)
            if !(column in dimensions)
                append!(values, skipmissing(df[!, column]))
            end
        end
        return filter(!iszero, values)
    end

    heuristic_price = bid_values("bidding_group_price_bid.csv")
    no_markup_price = bid_values("bidding_group_no_markup_price_bid.csv")
    equilibrium_price = bid_values("bidding_group_sfe_price_bid.csv")

    # The risk factor is nonzero here, so the heuristic bids carry the exogenous markup and the no-markup bids do not.
    # Without this, the fixture could not tell which of the two the equilibrium ingested.
    @test !isempty(heuristic_price)
    @test sort(heuristic_price) != sort(no_markup_price)

    # The equilibrium produced bids, and they are not simply a copy of the heuristic ones. A match here would mean the
    # equilibrium result was computed and then dropped, leaving clearing on the heuristic bids.
    @test !isempty(equilibrium_price)
    @test sort(equilibrium_price) != sort(heuristic_price)
    @test sort(equilibrium_price) != sort(no_markup_price)

    # The equilibrium marks the curves up strategically, so its prices must exceed the cost-based ones it ingested.
    @test maximum(equilibrium_price) > maximum(no_markup_price)
end

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH;
        test_only_subperiod_sum = [
            "deficit",
            "hydro_generation",
            "hydro_om_costs",
            "hydro_turbining",
            "hydro_minimum_outflow_violation_cost_expression",
        ],
        skipped_outputs = [
            "hydro_final_volume",
            "hydro_initial_volume",
        ],
    )
end

end
