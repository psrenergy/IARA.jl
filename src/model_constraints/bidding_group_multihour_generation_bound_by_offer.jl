#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_multihour_generation_bound_by_offer! end

function bidding_group_multihour_generation_bound_by_offer!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    # Define the bidding groups
    profile_bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_profile_bids])
    blks = subperiods(inputs)

    # Model variables
    bidding_group_generation_multihour = get_model_object(model, :bidding_group_generation_multihour)
    linear_combination_bid_segments_multihour = get_model_object(model, :linear_combination_bid_segments_multihour)

    # Model parameters
    bidding_group_quantity_offer_multihour = get_model_object(model, :bidding_group_quantity_offer_multihour)

    # Model constraints
    @constraint(
        model.jump_model,
        bidding_group_multihour_generation_bound_by_offer_multihour[
            blk in blks,
            bg in profile_bidding_groups,
            prf in 1:maximum_multihour_profiles(inputs, bg),
            bus in buses,
        ],
        bidding_group_generation_multihour[blk, bg, prf, bus] ==
        linear_combination_bid_segments_multihour[bg, prf] *
        bidding_group_quantity_offer_multihour[blk, bg, prf, bus],
    )

    return nothing
end

function bidding_group_multihour_generation_bound_by_offer!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function bidding_group_multihour_generation_bound_by_offer!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function bidding_group_multihour_generation_bound_by_offer!(
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
