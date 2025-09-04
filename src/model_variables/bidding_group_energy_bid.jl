#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_energy_bid! end

"""
    bidding_group_energy_bid!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild}) 

Add the bidding group energy bid variables to the model.
"""
function bidding_group_energy_bid!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    blks = subperiods(inputs)

    # Variables
    @variable(
        model.jump_model,
        bidding_group_energy_bid[
            blk in blks,
            bg in bidding_groups,
            bds in 1:number_of_bg_valid_bidding_segments(inputs, bg),
            bus in buses,
        ],
    )

    if is_price_maker(inputs, run_time_options)
        return nothing
    end

    # Time series
    spot_price_series = time_series_spot_price(inputs)

    # Objective function
    @expression(
        model.jump_model,
        bidding_group_revenue[
            blk in blks,
            bg in bidding_groups,
            bds in 1:number_of_bg_valid_bidding_segments(inputs, bg),
            bus in buses,
        ],
        -bidding_group_energy_bid[blk, bg, bds, bus] * spot_price_series[bus, blk],
    )

    for bg in bidding_groups
        for bds in 1:number_of_bg_valid_bidding_segments(inputs, bg)
            model.obj_exp +=
                sum(bidding_group_revenue[blk, bg, bds, bus] for blk in blks, bus in buses; init = 0) *
                money_to_thousand_money()
        end
    end

    return nothing
end

"""
    bidding_group_energy_bid!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemUpdate})

Updates the objective function coefficients for the bidding group energy bid variables.
"""
function bidding_group_energy_bid!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    buses = index_of_elements(inputs, Bus)
    blks = subperiods(inputs)

    if is_price_maker(inputs, run_time_options)
        return nothing
    end

    # Variables
    bidding_group_energy_bid = get_model_object(model, :bidding_group_energy_bid)

    # Time series
    spot_price_series = time_series_spot_price(inputs)

    for blk in blks, bg in bidding_groups, bds in 1:number_of_bg_valid_bidding_segments(inputs, bg), bus in buses
        set_objective_coefficient(
            model.jump_model,
            bidding_group_energy_bid[blk, bg, bds, bus],
            -spot_price_series[bus, blk] * money_to_thousand_money(),
        )
    end
    return nothing
end

"""
    bidding_group_energy_bid!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output file to store the bidding group energy bid variable values.
"""
function bidding_group_energy_bid!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    add_symbol_to_query_from_subproblem_result!(
        outputs,
        :bidding_group_energy_bid,
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
        output_name = "bidding_group_energy_bid",
        dimensions = ["period", "scenario", "subperiod", "bid_segment"],
        unit = "MWh",
        labels,
        run_time_options,
    )
    return nothing
end

"""
    bidding_group_energy_bid!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the bidding group energy bid variable values to the output.
"""
function bidding_group_energy_bid!(
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
        "bidding_group_energy_bid",
        simulation_results.data[:bidding_group_energy_bid].data;
        period,
        scenario,
        subscenario,
    )
    return nothing
end
