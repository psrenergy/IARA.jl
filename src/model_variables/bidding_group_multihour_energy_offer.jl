#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_multihour_energy_offer! end

function bidding_group_multihour_energy_offer!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    # Define the bidding groups
    profile_bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_profile_bids])
    blks = subperiods(inputs)

    quantity_offer_multihour_series = time_series_quantity_offer_multihour(inputs)
    price_offer_multihour_series = time_series_price_offer_multihour(inputs)

    # Variables
    @variable(
        model.jump_model,
        bidding_group_quantity_offer_multihour[
            blk in blks,
            bg in profile_bidding_groups,
            prf in 1:maximum_multihour_profiles(inputs, bg),
            bus in buses,
        ]
        in
        MOI.Parameter(quantity_offer_multihour_series[bg, bus, prf, blk])
    ) # MWh
    @variable(
        model.jump_model,
        bidding_group_price_offer_multihour[
            bg in profile_bidding_groups,
            prf in 1:maximum_multihour_profiles(inputs, bg),
        ]
        in
        MOI.Parameter(price_offer_multihour_series[bg, prf])
    ) # $/MWh

    # Variables
    @variable(
        model.jump_model,
        bidding_group_generation_multihour[
            blk in blks,
            bg in profile_bidding_groups,
            prf in 1:maximum_multihour_profiles(inputs, bg),
            bus in buses,
        ],
        lower_bound = 0.0,
    ) # MWh
    @variable(
        model.jump_model,
        linear_combination_bid_segments_multihour[
            bg in profile_bidding_groups,
            prf in 1:maximum_multihour_profiles(inputs, bg),
        ],
        lower_bound = 0.0,
        upper_bound = 1.0,
    )

    # Objective function
    @expression(
        model.jump_model,
        accepted_offers_multihour_cost[
            blk in blks,
            bg in profile_bidding_groups,
            prf in 1:maximum_multihour_profiles(inputs, bg),
            bus in buses,
        ],
        bidding_group_generation_multihour[blk, bg, prf, bus] *
        bidding_group_price_offer_multihour[bg, prf],
    )

    model.obj_exp += sum(accepted_offers_multihour_cost) * money_to_thousand_money()

    return nothing
end

function bidding_group_multihour_energy_offer!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    buses = index_of_elements(inputs, Bus)
    # Define the bidding groups
    profile_bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_profile_bids])
    blks = subperiods(inputs)

    quantity_offer_multihour_series = time_series_quantity_offer_multihour(inputs)
    price_offer_multihour_series = time_series_price_offer_multihour(inputs)

    bidding_group_price_offer_multihour = get_model_object(model, :bidding_group_price_offer_multihour)
    bidding_group_quantity_offer_multihour = get_model_object(model, :bidding_group_quantity_offer_multihour)

    for bg in profile_bidding_groups, prf in 1:maximum_multihour_profiles(inputs, bg)
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            bidding_group_price_offer_multihour[bg, prf],
            price_offer_multihour_series[bg, prf],
        )
    end
    for blk in blks, bg in profile_bidding_groups, prf in 1:maximum_multihour_profiles(inputs, bg), bus in buses
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            bidding_group_quantity_offer_multihour[blk, bg, prf, bus],
            quantity_offer_multihour_series[bg, bus, prf, blk],
        )
    end
    return nothing
end

function bidding_group_multihour_energy_offer!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    add_symbol_to_query_from_subproblem_result!(
        outputs,
        :bidding_group_generation_multihour,
    )

    labels = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.bidding_group,
        inputs.collections.bus;
        index_getter = all_buses,
        filters_to_apply_in_first_collection = [has_profile_bids],
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        run_time_options,
        output_name = "bidding_group_generation_multihour",
        dimensions = ["period", "scenario", "subperiod", "profile"],
        unit = "GWh",
        labels,
    )

    return nothing
end

function bidding_group_multihour_energy_offer!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    write_bid_output(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_generation_multihour",
        simulation_results.data[:bidding_group_generation_multihour].data;
        period,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        has_profile_bids = true,
        filters = [has_profile_bids],
    )
    return nothing
end
