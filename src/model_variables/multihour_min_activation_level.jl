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
    multihour_bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_multihour_bids])

    # Model variables
    if clearing_has_linearized_binary_variables(inputs, run_time_options)
        @variable(
            model.jump_model,
            minimum_activation_level_multihour_indicator[
                bg in multihour_bidding_groups,
                profile in 1:maximum_multihour_profiles(inputs, bg),
            ],
            lower_bound = 0.0,
            upper_bound = 1.0,
        )
    else
        @variable(
            model.jump_model,
            minimum_activation_level_multihour_indicator[
                bg in multihour_bidding_groups,
                profile in 1:maximum_multihour_profiles(inputs, bg),
            ], Bin
        )
    end

    # Model parameters
    minimum_activation_level_multihour_series = time_series_minimum_activation_level_multihour(inputs)

    @variable(
        model.jump_model,
        multihour_min_activation_level[
            bg in multihour_bidding_groups,
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
    multihour_bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_multihour_bids])

    minimum_activation_level_multihour_series = time_series_minimum_activation_level_multihour(inputs)
    multihour_min_activation_level = get_model_object(model, :multihour_min_activation_level)

    for bg in multihour_bidding_groups, profile in bidding_profiles(inputs)
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            multihour_min_activation_level[bg, profile],
            minimum_activation_level_multihour_series[index_among_multihour(inputs, bg), profile],
        )
    end

    if clearing_has_fixed_binary_variables(inputs, run_time_options)
        minimum_activation_level_multihour_indicator =
            get_model_object(model, :minimum_activation_level_multihour_indicator)

        ex_ante_physical_values = read_serialized_clearing_variable(
            inputs,
            RunTime_ClearingModelType.EX_ANTE_PHYSICAL,
            :minimum_activation_level_multihour_indicator;
            stage = model.stage,
            scenario = scenario,
        )

        fix.(
            minimum_activation_level_multihour_indicator,
            ex_ante_physical_values,
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
    if run_time_options.clearing_model_type == RunTime_ClearingModelType.EX_ANTE_PHYSICAL
        add_symbol_to_serialize!(outputs, :minimum_activation_level_multihour_indicator)
        add_symbol_to_query_from_subproblem_result!(outputs, :minimum_activation_level_multihour_indicator)
    end

    return nothing
end

function multihour_min_activation_level!(
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
