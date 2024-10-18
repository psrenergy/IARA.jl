#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_multihour_minimum_activation! end

function bidding_group_multihour_minimum_activation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    multihour_bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_multihour_bids])

    # Model variables
    linear_combination_bid_segments_multihour = get_model_object(model, :linear_combination_bid_segments_multihour)
    minimum_activation_level_multihour_indicator =
        get_model_object(model, :minimum_activation_level_multihour_indicator)

    # Model parameters
    minimum_activation_level_multihour = get_model_object(model, :multihour_min_activation_level)

    # Model constraints
    @constraint(
        model.jump_model,
        multihour_min_activation_level_ctr_down[
            bg in multihour_bidding_groups,
            profile in 1:maximum_multihour_profiles(inputs, bg),
        ],
        minimum_activation_level_multihour_indicator[bg, profile] * minimum_activation_level_multihour[bg, profile] <=
        linear_combination_bid_segments_multihour[bg, profile],
    )

    @constraint(
        model.jump_model,
        multihour_min_activation_level_ctr_up[
            bg in multihour_bidding_groups,
            profile in 1:maximum_multihour_profiles(inputs, bg),
        ],
        minimum_activation_level_multihour_indicator[bg, profile] >=
        linear_combination_bid_segments_multihour[bg, profile],
    )

    return nothing
end

function bidding_group_multihour_minimum_activation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function bidding_group_multihour_minimum_activation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function bidding_group_multihour_minimum_activation!(
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
