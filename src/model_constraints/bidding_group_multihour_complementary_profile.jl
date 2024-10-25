#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_multihour_complementary_profile! end

function bidding_group_multihour_complementary_profile!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    maximum_bidding_profiles = maximum_number_of_bidding_profiles(inputs)
    # Model variables
    linear_combination_bid_segments_multihour = get_model_object(model, :linear_combination_bid_segments_multihour)
    profile_bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_profile_bids])

    # Model parameters
    complementary_grouping_multihour_series = time_series_complementary_grouping_multihour(inputs)

    maximum_complementary_grouping_multihour = size(complementary_grouping_multihour_series)[2]
    complementary_grouping_multihour_sets = zeros(Int,
        length(bidding_groups),
        maximum_complementary_grouping_multihour,
        maximum_bidding_profiles,
    )

    for (i_bg, bg) in enumerate(profile_bidding_groups), prf in 1:maximum_multihour_profiles(inputs, bg),
        cp_idx in 1:maximum_complementary_grouping_multihour

        complementary_group = complementary_grouping_multihour_series[i_bg, cp_idx, prf]
        complementary_grouping_multihour_sets[bg, cp_idx, prf] = complementary_group
    end

    # Model constraints
    @constraint(
        model.jump_model,
        bidding_group_multihour_complementary_profile_multihour[
            bg in profile_bidding_groups,
            cp_idx in 1:maximum_complementary_grouping_multihour;
            has_complementary_grouping_multihour(
                complementary_grouping_multihour_sets[bg, cp_idx, :],
            ),
        ],
        sum(
            linear_combination_bid_segments_multihour[bg, prf]
            for prf in 1:maximum_multihour_profiles(inputs, bg)
            if complementary_grouping_multihour_sets[bg, cp_idx, prf] == 1;
            init = 0,
        ) <= 1,
    )

    return nothing
end

function has_complementary_grouping_multihour(complementary_grouping_multihour_set::Array{Int, 1})
    return sum(complementary_grouping_multihour_set) > 0
end

function bidding_group_multihour_complementary_profile!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function bidding_group_multihour_complementary_profile!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function bidding_group_multihour_complementary_profile!(
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
