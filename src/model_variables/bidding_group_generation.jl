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
    placeholder_quantity_bid_series = 0.0
    placeholder_price_bid_series = 0.0

    # Parameters
    @variable(
        model.jump_model,
        bidding_group_quantity_bid[
            blk in blks,
            bg in bidding_groups,
            bds in 1:number_of_bg_valid_bidding_segments(inputs, bg),
            bus in buses,
        ]
        in
        MOI.Parameter(placeholder_quantity_bid_series)
    ) # MWh
    @variable(
        model.jump_model,
        bidding_group_price_bid[
            blk in blks,
            bg in bidding_groups,
            bds in 1:number_of_bg_valid_bidding_segments(inputs, bg),
            bus in buses,
        ]
        in
        MOI.Parameter(placeholder_price_bid_series)
    ) # $/MWh

    # Variables
    @variable(
        model.jump_model,
        bidding_group_generation[
            blk in blks,
            bg in bidding_groups,
            bds in 1:number_of_bg_valid_bidding_segments(inputs, bg),
            bus in buses,
        ],
    ) # MWh
    @variable(
        model.jump_model,
        linear_combination_bid_segments[
            blk in blks,
            bg in bidding_groups,
            bds in 1:number_of_bg_valid_bidding_segments(inputs, bg),
            bus in buses,
        ],
        lower_bound = 0.0,
        upper_bound = 1.0,
    )

    # Objective function
    @expression(
        model.jump_model,
        accepted_bids_cost[
            blk in blks,
            bg in bidding_groups,
            bds in 1:number_of_bg_valid_bidding_segments(inputs, bg),
            bus in buses,
        ],
        bidding_group_generation[blk, bg, bds, bus] * bidding_group_price_bid[blk, bg, bds, bus],
    )

    model.obj_exp += sum(accepted_bids_cost) * money_to_thousand_money()

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
    bidding_group_quantity_bid = get_model_object(model, :bidding_group_quantity_bid)
    bidding_group_price_bid = get_model_object(model, :bidding_group_price_bid)

    # Time series
    quantity_bid_series = time_series_quantity_bid(inputs, simulation_period, simulation_trajectory)
    price_bid_series = time_series_price_bid(inputs, simulation_period, simulation_trajectory)

    adjust_quantity_bid_for_ex_post!(inputs, run_time_options, quantity_bid_series, subscenario)

    # Model variables
    linear_combination_bid_segments = get_model_object(model, :linear_combination_bid_segments)

    for blk in blks, bg in bidding_groups, bds in 1:number_of_bg_valid_bidding_segments(inputs, bg), bus in buses
        quantity_bid = quantity_bid_series[bg, bus, bds, blk]
        set_parameter_value(bidding_group_quantity_bid[blk, bg, bds, bus], quantity_bid)
        set_parameter_value(bidding_group_price_bid[blk, bg, bds, bus], price_bid_series[bg, bus, bds, blk])
        deactivate_or_reactivate_bid_segment!(linear_combination_bid_segments[blk, bg, bds, bus], quantity_bid)
    end
    return nothing
end

"""
    deactivate_or_reactivate_bid_segment!(linear_combination::JuMP.VariableRef, quantity_bid::Float64)

Pin the convex combination weight of a bid segment to zero when the segment carries no quantity, and release it again
when it does.

The number of bid segments is fixed before `build_model`, so every period is built for the largest count any
period needs. A segment whose quantity is zero in the current period still leaves the constraint
`bidding_group_generation == linear_combination * bidding_group_quantity_bid` in the model, where it degenerates
to `bidding_group_generation == 0` and leaves the weight free over `[0, 1]` with no cost and no other constraint.
Those unpriced free variables are pure dual degeneracy, and there can be many of them: the supply function
equilibrium sizes every agent by a loose analytic bound, so most segments are zero in any given period. Fixing the
weight lets the solver's presolve remove the segment instead of pivoting on it.
"""
function deactivate_or_reactivate_bid_segment!(linear_combination::JuMP.VariableRef, quantity_bid::Float64)
    segment_is_empty = abs(quantity_bid) <= DEFAULT_TOLERANCE
    if segment_is_empty
        if !JuMP.is_fixed(linear_combination)
            # `force` is required because the variable is built with the `[0, 1]` bounds that `unfix` restores below.
            JuMP.fix(linear_combination, 0.0; force = true)
        end
    elseif JuMP.is_fixed(linear_combination)
        JuMP.unfix(linear_combination)
        # `unfix` drops the bounds along with the fixed value, so the original ones have to be set again.
        JuMP.set_lower_bound(linear_combination, 0.0)
        JuMP.set_upper_bound(linear_combination, 1.0)
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
        [:bidding_group_generation],
    )
    if should_write_ex_post_quantity_bid_output_file(
        inputs,
        run_time_options,
    )
        add_symbol_to_query_from_subproblem_result!(
            outputs,
            [:bidding_group_quantity_bid],
        )
    end

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
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])

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

    if should_write_ex_post_quantity_bid_output_file(
        inputs,
        run_time_options,
    )
        write_bid_output(
            outputs,
            inputs,
            run_time_options,
            "bidding_group_energy_bid_ex_post",
            simulation_results.data[:bidding_group_quantity_bid].data;
            period,
            scenario,
            subscenario,
            multiply_by = MW_to_GW(),
            has_profile_bids = false,
            filters = [has_generation_besides_virtual_reservoirs],
            suppress_construction_type_suffix = true,
        )
    end

    return nothing
end
