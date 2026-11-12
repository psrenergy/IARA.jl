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

module TestCase07SupplyFunctionEquilibriumBgRenewable

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

# Bids of one "bidding group - bus" pair in one period and scenario, indexed by (bid_segment, subperiod).
function bid_matrix(bids::DataFrame, agent::String, period::Int, scenario::Int)
    rows = bids[(bids.period.==period).&(bids.scenario.==scenario), :]
    matrix = zeros(maximum(rows.bid_segment), maximum(rows.subperiod))
    for row in eachrow(rows)
        matrix[row.bid_segment, row.subperiod] = row[agent]
    end
    return matrix
end

# Split across subperiods of the cheapest `cumulative_quantity` MWh of an agent's original bids, taken in ascending order
# of their price averaged over subperiods. The prices of this case are unique within each agent.
function merit_order_split(quantity::Matrix{Float64}, price::Matrix{Float64}, cumulative_quantity::Float64)
    aggregated_quantity = vec(sum(quantity; dims = 2))
    aggregated_price = vec(sum(quantity .* price; dims = 2)) ./ aggregated_quantity
    split = zeros(size(quantity, 2))
    remaining_quantity = cumulative_quantity
    for segment in sortperm(aggregated_price)
        if aggregated_quantity[segment] > 0.0 && remaining_quantity > 0.0
            taken_quantity = min(remaining_quantity, aggregated_quantity[segment])
            split .+= taken_quantity .* quantity[segment, :] ./ aggregated_quantity[segment]
            remaining_quantity -= taken_quantity
        end
    end
    return split
end

# The equilibrium runs on bids aggregated over subperiods, but it keeps each agent's merit order: the n-th MWh of its
# curve is the n-th MWh of its original bids. So every equilibrium bid segment must take its energy from the subperiods
# that the original bids at the same cumulative quantity come from. An even split would make "mixed_bg" offer energy
# from its renewable unit in subperiod 1, where that unit has none.
@testset "Supply function equilibrium bids follow the subperiod shape of the original bids" begin
    outputs_dir = joinpath(PATH, "outputs")
    original_quantity = CSV.read(joinpath(outputs_dir, "bidding_group_energy_bid.csv"), DataFrame)
    original_price = CSV.read(joinpath(outputs_dir, "bidding_group_no_markup_price_bid.csv"), DataFrame)
    equilibrium_quantity = CSV.read(joinpath(outputs_dir, "bidding_group_sfe_energy_bid.csv"), DataFrame)

    dimensions = ["period", "scenario", "subperiod", "bid_segment"]
    agents = filter(!in(dimensions), names(equilibrium_quantity))
    @test "mixed_bg - bus_1" in agents
    periods = unique(equilibrium_quantity.period)
    scenarios = unique(equilibrium_quantity.scenario)

    for agent in agents, period in periods, scenario in scenarios
        quantity = bid_matrix(original_quantity, agent, period, scenario)
        price = bid_matrix(original_price, agent, period, scenario)
        equilibrium = bid_matrix(equilibrium_quantity, agent, period, scenario)

        if agent == "mixed_bg - bus_1"
            # The fixture must offer different energy across subperiods, or an even split would pass too.
            original_by_subperiod = vec(sum(quantity; dims = 1))
            @test original_by_subperiod[1] < original_by_subperiod[end]
        end

        # The bid segments follow one another along the aggregated curve, each covering the stretch where the previous
        # one ended.
        segment_end = cumsum(vec(sum(equilibrium; dims = 2)))
        segment_start = vcat(0.0, segment_end[1:end-1])
        expected = zeros(size(equilibrium))
        for segment in axes(equilibrium, 1)
            expected[segment, :] =
                merit_order_split(quantity, price, segment_end[segment]) .-
                merit_order_split(quantity, price, segment_start[segment])
        end
        # The outputs are rounded to 6 decimal places, and that rounding builds up along the cumulative quantities.
        @test all(isapprox.(equilibrium, expected; atol = 1e-3))

        # In particular, no subperiod is offered more energy than the original bids hold in it.
        @test all(vec(sum(equilibrium; dims = 1)) .<= vec(sum(quantity; dims = 1)) .+ 1e-3)
    end
end

end
