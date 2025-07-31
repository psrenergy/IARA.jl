#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function link_bids_and_generation! end

"""
    link_bids_and_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the link between bids and generation constraints to the model.
"""
function link_bids_and_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    blks = subperiods(inputs)
    # Generation variables
    hydro_units =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, !is_associated_with_some_virtual_reservoir])
    thermal_units = index_of_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing])
    renewable_units = index_of_elements(inputs, RenewableUnit; run_time_options, filters = [is_existing])
    battery_units = index_of_elements(inputs, BatteryUnit; run_time_options, filters = [is_existing])
    hydro_generation =
        if any_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, !is_associated_with_some_virtual_reservoir])
            get_model_object(model, :hydro_generation)
        end
    demand_units = index_of_elements(inputs, DemandUnit; filters = [is_existing])
    thermal_generation = if any_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing])
        get_model_object(model, :thermal_generation)
    end
    renewable_generation = if any_elements(inputs, RenewableUnit; run_time_options, filters = [is_existing])
        get_model_object(model, :renewable_generation)
    end
    battery_unit_generation = if any_elements(inputs, BatteryUnit; run_time_options, filters = [is_existing])
        get_model_object(model, :battery_unit_generation)
    end
    attended_elastic_demand = if any_elements(inputs, DemandUnit; run_time_options, filters = [is_existing, is_elastic])
        get_model_object(model, :attended_elastic_demand)
    end
    # Bid variables
    bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_generation_besides_virtual_reservoirs])
    
    @expression(
        model.jump_model,
        all_bidding_group_generation[
            blk in blks,
            bg in bidding_groups,
            bus in buses,
        ],
        AffExpr(0),
    )

    if is_price_maker(inputs, run_time_options) || is_price_taker(inputs, run_time_options)
        bidding_group_energy_bid = get_model_object(model, :bidding_group_energy_bid)
    else
        if has_any_profile_bids(inputs)
            bidding_group_generation_profile = get_model_object(model, :bidding_group_generation_profile)
        end
        if has_any_simple_bids(inputs)
            bidding_group_generation = get_model_object(model, :bidding_group_generation)
        end
    end
    
    for blk in blks, bg in bidding_groups, bus in buses
        all_bidding_group_generation[blk, bg, bus] =
            if is_price_maker(inputs, run_time_options) || is_price_taker(inputs, run_time_options)
                sum(
                    bidding_group_energy_bid[blk, bg, bds, bus] for
                    bds in 1:number_of_bg_valid_bidding_segments(inputs, bg);
                    init = 0.0,
                )
            else
                if has_any_simple_bids(inputs)
                    sum(
                        bidding_group_generation[blk, bg, bds, bus] for
                        bds in 1:number_of_bg_valid_bidding_segments(inputs, bg);
                        init = 0.0,
                    )
                else
                    0.0
                end +
                if has_any_profile_bids(inputs)
                    sum(
                        bidding_group_generation_profile[blk, bg, prf, bus] for
                        prf in 1:number_of_valid_profiles(inputs, bg);
                        init = 0.0,
                    )
                else
                    0.0
                end
            end
    end

    @constraint(
        model.jump_model,
        link_bids_and_generation[blk in blks, bg in bidding_groups, bus in buses],
        all_bidding_group_generation[blk, bg, bus]
        ==
        sum(
            hydro_generation[blk, h] for h in hydro_units
            if hydro_unit_bus_index(inputs, h) == bus
            &&
            hydro_unit_bidding_group_index(inputs, h) == bg;
            init = 0.0,
        ) +
        sum(
            thermal_generation[blk, t] for t in thermal_units
            if thermal_unit_bus_index(inputs, t) == bus
            &&
            thermal_unit_bidding_group_index(inputs, t) == bg;
            init = 0.0,
        ) +
        sum(
            renewable_generation[blk, r] for r in renewable_units
            if renewable_unit_bus_index(inputs, r) == bus
            &&
            renewable_unit_bidding_group_index(inputs, r) == bg;
            init = 0.0,
        ) +
        sum(
            battery_unit_generation[blk, bat] for bat in battery_units
            if battery_unit_bus_index(inputs, bat) == bus
            &&
            battery_unit_bidding_group_index(inputs, bat) == bg;
            init = 0.0,
        )
        # Elastic demand bids are represented as negative quantities (-MW) because they indicate:
        #   - Potential load reduction (if the bid price is met)
        #
        # In a bid group that consists only of flexible demand:
        #   Total Bid Quantity = Σ(Elastic Demand Bids)
        #                       = Σ(- MW bids)
        #
        # Example:
        #   - Factory A bids a elastic demand of 20 MW
        #   - Factory B bids a elastic demand of 30 MW
        #   → The total bid quantity for the group = -50 MW (representing the total load reduction)
        -
        if any_elements(inputs, DemandUnit; filters = [is_existing, is_elastic])
            sum(
                attended_elastic_demand[blk, d] for d in demand_units
                if demand_unit_bus_index(inputs, d) == bus
                &&
                    demand_unit_bidding_group_index(inputs, d) == bg;
                init = 0.0,
            )
        else
            0.0
        end
    )
    return nothing
end
function link_bids_and_generation!(
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
function link_bids_and_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    # TODO: Just price taker?
    if is_price_taker(inputs, run_time_options)
        add_custom_recorder_to_query_from_subproblem_result!(
            outputs,
            :bidding_group_price_bid,
            constraint_dual_recorder(inputs, :link_bids_and_generation),
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
            output_name = "bidding_group_price_bid",
            dimensions = ["period", "scenario", "subperiod", "bid_segment"],
            unit = "\$/MWh",
            labels,
            run_time_options,
        )
    end
    return nothing
end
function link_bids_and_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    # TODO: Just price taker?
    if is_price_taker(inputs, run_time_options)
        # Fill the 4 dimensional array with the same prices for all bidding segments

        max_bg_bidding_segments = maximum_number_of_bg_bidding_segments(inputs)
        
        # Get the original 3D data
        original_data = simulation_results.data[:bidding_group_price_bid].data
        
        # Create 4D array by repeating values across the bidding segments dimension
        bidding_group_price_bid = repeat(
            original_data,
            outer = (1, 1, 1, max_bg_bidding_segments)
        )
        write_bid_output(
            outputs,
            inputs,
            run_time_options,
            "bidding_group_price_bid",
            bidding_group_price_bid;
            period,
            scenario,
            subscenario,
            multiply_by = (-1) / money_to_thousand_money(),
        )
    end
    return nothing
end
