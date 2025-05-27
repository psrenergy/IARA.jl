#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_profile_complementary_profile! end

"""
    bidding_group_profile_complementary_profile!(
        model,
        inputs,
        run_time_options,
        ::Type{SubproblemBuild},
    )

Add the bidding group profile complementary profile constraints to the model.
"""
function bidding_group_profile_complementary_profile!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_generation_besides_virtual_reservoirs])
    # Model variables
    linear_combination_bid_segments_profile = get_model_object(model, :linear_combination_bid_segments_profile)

    # Model parameters
    placeholder_scenario = 1
    complementary_grouping_profile_series =
        time_series_complementary_grouping_profile(inputs, model.node, placeholder_scenario)

    maximum_complementary_grouping_profile = size(complementary_grouping_profile_series)[2]
    complementary_grouping_profile_sets = zeros(Int,
        length(bidding_groups),
        maximum_complementary_grouping_profile,
        maximum_number_of_profiles(inputs),
    )

    for (i_bg, bg) in enumerate(bidding_groups), prf in 1:number_of_valid_profiles(inputs, bg),
        cp_idx in 1:maximum_complementary_grouping_profile

        complementary_group = complementary_grouping_profile_series[i_bg, cp_idx, prf]
        complementary_grouping_profile_sets[bg, cp_idx, prf] = complementary_group
    end

    # Model constraints
    @constraint(
        model.jump_model,
        bidding_group_profile_complementary_profile_profile[
            bg in bidding_groups,
            cp_idx in 1:maximum_complementary_grouping_profile;
            has_complementary_grouping_profile(
                complementary_grouping_profile_sets[bg, cp_idx, :],
            ),
        ],
        sum(
            linear_combination_bid_segments_profile[bg, prf]
            for prf in 1:number_of_valid_profiles(inputs, bg)
            if complementary_grouping_profile_sets[bg, cp_idx, prf] == 1;
            init = 0,
        ) <= 1,
    )

    return nothing
end

"""
    has_complementary_grouping_profile(complementary_grouping_profile_set::Array{Int, 1})

Returns true if the complementary grouping profile set has at least one element equal to 1.
"""
function has_complementary_grouping_profile(complementary_grouping_profile_set::Array{Int, 1})
    return sum(complementary_grouping_profile_set) > 0
end

function bidding_group_profile_complementary_profile!(
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

function bidding_group_profile_complementary_profile!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function bidding_group_profile_complementary_profile!(
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
