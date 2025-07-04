#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_profile_precedence! end

"""
    bidding_group_profile_precedence!(
        model,
        inputs,
        run_time_options,
        ::Type{SubproblemBuild},
    )

Add the bidding group profile precedence constraints to the model.
"""
function bidding_group_profile_precedence!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    # Model variables
    linear_combination_bid_segments_profile = get_model_object(model, :linear_combination_bid_segments_profile)
    bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_generation_besides_virtual_reservoirs])

    parent_profile_bids = zeros(Int,
        length(bidding_groups),
        maximum_number_of_profiles(inputs),
    )

    placeholder_scenario = 1
    for (i_bg, bg) in enumerate(bidding_groups), profile in 1:number_of_valid_profiles(inputs, bg)
        parent_profile_bids[bg, profile] =
            time_series_parent_profile(inputs, model.node, placeholder_scenario)[i_bg, profile]
        if parent_profile_bids[bg, profile] == profile
            error("Bidding group $bg profile $profile is its own parent")
        end
    end

    # Model constraints
    @constraint(
        model.jump_model,
        bidding_group_profile_precedence[
            bg in bidding_groups,
            profile in 1:number_of_valid_profiles(inputs, bg);
            is_valid_parent(parent_profile_bids[bg, profile], profile),
        ],
        linear_combination_bid_segments_profile[bg, profile]
        <=
        linear_combination_bid_segments_profile[bg, parent_profile_bids[bg, profile]],
    )

    return nothing
end

function is_valid_parent(parent_bid_profile::Int, profile::Int)
    return parent_bid_profile != 0
end

function bidding_group_profile_precedence!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function bidding_group_profile_precedence!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function bidding_group_profile_precedence!(
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
