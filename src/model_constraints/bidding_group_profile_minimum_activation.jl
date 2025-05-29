#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_profile_minimum_activation! end

"""
    bidding_group_profile_minimum_activation!(
        model,
        inputs,
        run_time_options,
        ::Type{SubproblemBuild},
    )

Add the bidding group profile minimum activation constraints to the model.
"""
function bidding_group_profile_minimum_activation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    bidding_groups =
        index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])

    # Model variables
    linear_combination_bid_segments_profile = get_model_object(model, :linear_combination_bid_segments_profile)
    minimum_activation_level_profile_indicator =
        get_model_object(model, :minimum_activation_level_profile_indicator)

    # Model parameters
    minimum_activation_level_profile = get_model_object(model, :profile_min_activation_level)

    # Model constraints
    @constraint(
        model.jump_model,
        profile_min_activation_level_ctr_down[
            bg in bidding_groups,
            profile in 1:number_of_valid_profiles(inputs, bg),
        ],
        minimum_activation_level_profile_indicator[bg, profile] * minimum_activation_level_profile[bg, profile] <=
        linear_combination_bid_segments_profile[bg, profile],
    )

    @constraint(
        model.jump_model,
        profile_min_activation_level_ctr_up[
            bg in bidding_groups,
            profile in 1:number_of_valid_profiles(inputs, bg),
        ],
        minimum_activation_level_profile_indicator[bg, profile] >=
        linear_combination_bid_segments_profile[bg, profile],
    )

    return nothing
end

function bidding_group_profile_minimum_activation!(
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

function bidding_group_profile_minimum_activation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function bidding_group_profile_minimum_activation!(
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
