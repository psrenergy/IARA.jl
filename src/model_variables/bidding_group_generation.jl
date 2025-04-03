#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_generation! end

"""
    bidding_group_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the bidding group generation variables to the model.
"""
function bidding_group_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    blks = subperiods(inputs)

    # Time series
    placeholder_quantity_offer_series = 0.0
    placeholder_price_offer_series = 0.0

    valid_segments = get_maximum_valid_segments(inputs)

    # Parameters
    @variable(
        model.jump_model,
        bidding_group_quantity_offer[
            blk in blks,
            bg in bidding_groups,
            bds in 1:valid_segments[bg],
            bus in buses,
        ]
        in
        MOI.Parameter(placeholder_quantity_offer_series)
    ) # MWh
    @variable(
        model.jump_model,
        bidding_group_price_offer[
            blk in blks,
            bg in bidding_groups,
            bds in 1:valid_segments[bg],
            bus in buses,
        ]
        in
        MOI.Parameter(placeholder_price_offer_series)
    ) # $/MWh

    # Variables
    @variable(
        model.jump_model,
        bidding_group_generation[
            blk in blks,
            bg in bidding_groups,
            bds in 1:valid_segments[bg],
            bus in buses,
        ],
        lower_bound = 0.0,
    ) # MWh
    @variable(
        model.jump_model,
        linear_combination_bid_segments[
            blk in blks,
            bg in bidding_groups,
            bds in 1:valid_segments[bg],
            bus in buses,
        ],
        lower_bound = 0.0,
        upper_bound = 1.0,
    )

    # Objective function
    @expression(
        model.jump_model,
        accepted_offers_cost[
            blk in blks,
            bg in bidding_groups,
            bds in 1:valid_segments[bg],
            bus in buses,
        ],
        bidding_group_generation[blk, bg, bds, bus] * bidding_group_price_offer[blk, bg, bds, bus],
    )

    model.obj_exp += sum(accepted_offers_cost) * money_to_thousand_money()

    return nothing
end

"""
    bidding_group_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, scenario, subscenario, ::Type{SubproblemUpdate})

Updates the objective function coefficients for the bidding group generation variables.
"""
function bidding_group_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    blks = subperiods(inputs)

    # Model parameters
    bidding_group_quantity_offer = get_model_object(model, :bidding_group_quantity_offer)
    bidding_group_price_offer = get_model_object(model, :bidding_group_price_offer)

    # Time series
    quantity_offer_series = time_series_quantity_offer(inputs, model.node, scenario)
    price_offer_series = time_series_price_offer(inputs, model.node, scenario)

    adjust_quantity_offer_for_ex_post!(inputs, run_time_options, quantity_offer_series, subscenario)

    valid_segments = get_maximum_valid_segments(inputs)

    for blk in blks, bg in bidding_groups, bds in 1:valid_segments[bg], bus in buses
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            bidding_group_quantity_offer[blk, bg, bds, bus],
            quantity_offer_series[bg, bus, bds, blk],
        )
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            bidding_group_price_offer[blk, bg, bds, bus],
            price_offer_series[bg, bus, bds, blk],
        )
    end
    return nothing
end

"""
    bidding_group_generation!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output file to store the bidding group generation variable values.
"""
function bidding_group_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    add_symbol_to_query_from_subproblem_result!(
        outputs,
        :bidding_group_generation,
    )

    labels = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.bidding_group,
        inputs.collections.bus;
        index_getter = all_buses,
        filters_to_apply_in_first_collection = [has_generation_besides_virtual_reservoirs],
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "bidding_group_generation",
        dimensions = ["period", "scenario", "subperiod", "bid_segment"],
        unit = "GWh",
        labels,
        run_time_options,
    )

    return nothing
end

"""
    bidding_group_generation!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the bidding group generation variable values to the output.
"""
function bidding_group_generation!(
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
        "bidding_group_generation",
        simulation_results.data[:bidding_group_generation].data;
        period,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        has_profile_bids = false,
        filters = [has_generation_besides_virtual_reservoirs],
    )

    return nothing
end
