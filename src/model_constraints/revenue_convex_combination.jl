#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function revenue_convex_combination! end

"""
    revenue_convex_combination!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the revenue convex combination constraints to the model.
"""
function revenue_convex_combination!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    blks = subperiods(inputs)
    bid_segments = bidding_segments(inputs)
    buses = index_of_elements(inputs, Bus)

    # Number of points in the convex hull for each bus and subperiod
    convex_hull_length = length.(asset_owner_revenue_convex_hull(inputs))

    # Model variables
    convex_revenue_coefficients = get_model_object(model, :convex_revenue_coefficients)
    bidding_group_energy_offer = get_model_object(model, :bidding_group_energy_offer)

    # Model parameters
    convex_hull_point_quantity = get_model_object(model, :convex_hull_point_quantity)

    # Model constraints
    @constraint(
        model.jump_model,
        convex_revenue_coefficients_sum[
            blk in blks,
            bus in buses_represented_for_strategic_bidding(inputs),
        ],
        sum(
            convex_revenue_coefficients[blk, bus, v]
            for v in 1:convex_hull_length[bus, blk]
        ) == 1.0,
    )

    if aggregate_buses_for_strategic_bidding(inputs)
        @constraint(
            model.jump_model,
            energy_quantity_convex_combination[
                blk in blks,
                agg_bus in buses_represented_for_strategic_bidding(inputs),
            ],
            sum(
                convex_revenue_coefficients[blk, agg_bus, v]
                *
                convex_hull_point_quantity[blk, agg_bus, v]
                for v in 1:convex_hull_length[agg_bus, blk]
            ) ==
            sum(
                bidding_group_energy_offer[blk, bg, bds, bus] for
                bus in buses,
                bg in bidding_groups,
                bds in bid_segments
            ),
        )
    else
        @constraint(
            model.jump_model,
            energy_quantity_convex_combination[
                blk in blks,
                bus in buses,
            ],
            sum(
                convex_revenue_coefficients[blk, bus, v]
                *
                convex_hull_point_quantity[blk, bus, v]
                for v in 1:convex_hull_length[bus, blk]
            ) ==
            sum(
                bidding_group_energy_offer[blk, bg, bds, bus] for
                bg in bidding_groups,
                bds in bid_segments
            ),
        )
    end

    return nothing
end

function revenue_convex_combination!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function revenue_convex_combination!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function revenue_convex_combination!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
