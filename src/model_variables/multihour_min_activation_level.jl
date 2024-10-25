#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function multihour_min_activation_level! end

function multihour_min_activation_level!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    profile_bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_profile_bids])

    # Model variables
    @variable(
        model.jump_model,
        minimum_activation_level_multihour_indicator[
            bg in profile_bidding_groups,
            profile in 1:maximum_multihour_profiles(inputs, bg),
        ], Bin
    )

    if use_binary_variables(inputs)
        add_symbol_to_integer_variables_list!(run_time_options, :minimum_activation_level_multihour_indicator)
    end

    # Model parameters
    minimum_activation_level_multihour_series = time_series_minimum_activation_level_multihour(inputs)

    @variable(
        model.jump_model,
        multihour_min_activation_level[
            bg in profile_bidding_groups,
            profile in 1:maximum_multihour_profiles(inputs, bg),
        ]
        in
        MOI.Parameter(minimum_activation_level_multihour_series[index_among_multihour(inputs, bg), profile])
    )

    return nothing
end

function multihour_min_activation_level!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    # Define the bidding groups
    profile_bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_profile_bids])

    minimum_activation_level_multihour_series = time_series_minimum_activation_level_multihour(inputs)
    multihour_min_activation_level = get_model_object(model, :multihour_min_activation_level)

    for bg in profile_bidding_groups, profile in bidding_profiles(inputs)
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            multihour_min_activation_level[bg, profile],
            minimum_activation_level_multihour_series[index_among_multihour(inputs, bg), profile],
        )
    end

    return nothing
end

function multihour_min_activation_level!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    if run_time_options.clearing_model_procedure != RunTime_ClearingProcedure.EX_POST_COMMERCIAL
        if use_binary_variables(inputs)
            add_symbol_to_serialize!(outputs, :minimum_activation_level_multihour_indicator)
        end
        add_symbol_to_query_from_subproblem_result!(outputs, :minimum_activation_level_multihour_indicator)
    end

    return nothing
end

function multihour_min_activation_level!(
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
