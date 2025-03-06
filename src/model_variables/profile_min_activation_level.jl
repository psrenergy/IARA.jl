#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function profile_min_activation_level! end

"""
    profile_min_activation_level!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the profile minimum activation level variables to the model.
"""
function profile_min_activation_level!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    bidding_groups =
        index_of_elements(inputs, BiddingGroup)

    valid_profiles = get_maximum_valid_profiles(inputs)

    # Model variables
    @variable(
        model.jump_model,
        minimum_activation_level_profile_indicator[
            bg in bidding_groups,
            profile in 1:valid_profiles[bg],
        ], Bin
    )

    if use_binary_variables(inputs, run_time_options)
        add_symbol_to_integer_variables_list!(run_time_options, :minimum_activation_level_profile_indicator)
    end

    # Model parameters
    placeholder_scenario = 1
    minimum_activation_level_profile_series =
        time_series_minimum_activation_level_profile(inputs, model.period, placeholder_scenario)

    @variable(
        model.jump_model,
        profile_min_activation_level[
            bg in bidding_groups,
            profile in 1:valid_profiles[bg],
        ]
        in
        MOI.Parameter(minimum_activation_level_profile_series[bg, profile])
    )

    return nothing
end

"""
    profile_min_activation_level!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, scenario, subscenario, ::Type{SubproblemUpdate})

Updates the profile minimum activation level variables in the model.
"""
function profile_min_activation_level!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    # Define the bidding groups
    bidding_groups =
        index_of_elements(inputs, BiddingGroup)

    minimum_activation_level_profile_series =
        time_series_minimum_activation_level_profile(inputs, model.period, scenario)
    profile_min_activation_level = get_model_object(model, :profile_min_activation_level)

    valid_profiles = get_maximum_valid_profiles(inputs)

    for bg in bidding_groups, profile in 1:valid_profiles[bg]
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            profile_min_activation_level[bg, profile],
            minimum_activation_level_profile_series[bg, profile],
        )
    end

    return nothing
end

"""
    profile_min_activation_level!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Adds symbols to serialize and query the profile minimum activation level variables.
"""
function profile_min_activation_level!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    if run_time_options.clearing_model_subproblem != RunTime_ClearingSubproblem.EX_POST_COMMERCIAL
        if use_binary_variables(inputs, run_time_options)
            add_symbol_to_serialize!(outputs, :minimum_activation_level_profile_indicator)
        end
        add_symbol_to_query_from_subproblem_result!(outputs, :minimum_activation_level_profile_indicator)
    end

    return nothing
end

function profile_min_activation_level!(
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
