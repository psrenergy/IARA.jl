#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_generation_bound_by_offer! end

function bidding_group_generation_bound_by_offer!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    simple_bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_simple_bids])
    blks = blocks(inputs)

    # Model variables
    bidding_group_generation = get_model_object(model, :bidding_group_generation)
    linear_combination_bid_segments = get_model_object(model, :linear_combination_bid_segments)

    # Model parameters
    bidding_group_quantity_offer = get_model_object(model, :bidding_group_quantity_offer)

    # Model constraints
    @constraint(
        model.jump_model,
        bidding_group_generation_bound_by_offer[
            blk in blks,
            bg in simple_bidding_groups,
            bds in 1:maximum_bid_segments(inputs, bg),
            bus in buses,
        ],
        bidding_group_generation[blk, bg, bds, bus] ==
        linear_combination_bid_segments[blk, bg, bds, bus] *
        bidding_group_quantity_offer[blk, bg, bds, bus],
    )

    return nothing
end

function bidding_group_generation_bound_by_offer!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function bidding_group_generation_bound_by_offer!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function bidding_group_generation_bound_by_offer!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
