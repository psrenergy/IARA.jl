#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function link_offers_and_generation! end

"""
    link_offers_and_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the link between offers and generation constraints to the model.
"""
function link_offers_and_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    blks = subperiods(inputs)
    # Generation variables
    hydro_units =
        index_of_elements(inputs, HydroUnit; filters = [is_existing, !is_associated_with_some_virtual_reservoir])
    thermal_units = index_of_elements(inputs, ThermalUnit; filters = [is_existing])
    renewable_units = index_of_elements(inputs, RenewableUnit; filters = [is_existing])
    battery_units = index_of_elements(inputs, BatteryUnit; filters = [is_existing])
    hydro_generation =
        if any_elements(inputs, HydroUnit; filters = [is_existing, !is_associated_with_some_virtual_reservoir])
            get_model_object(model, :hydro_generation)
        end
    demand_units = index_of_elements(inputs, DemandUnit; filters = [is_existing])
    thermal_generation = if any_elements(inputs, ThermalUnit; filters = [is_existing])
        get_model_object(model, :thermal_generation)
    end
    renewable_generation = if any_elements(inputs, RenewableUnit; filters = [is_existing])
        get_model_object(model, :renewable_generation)
    end
    battery_unit_generation = if any_elements(inputs, BatteryUnit; filters = [is_existing])
        get_model_object(model, :battery_unit_generation)
    end
    attended_elastic_demand = if any_elements(inputs, DemandUnit; filters = [is_existing, is_elastic])
        get_model_object(model, :attended_elastic_demand)
    end
    # Offer variables
    bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_generation_besides_virtual_reservoirs])

    if has_any_profile_bids(inputs)
        bidding_group_generation_profile = get_model_object(model, :bidding_group_generation_profile)
    end
    if has_any_simple_bids(inputs)
        bidding_group_generation = get_model_object(model, :bidding_group_generation)
    end

    @constraint(
        model.jump_model,
        link_offers_and_generation[blk in blks, bg in bidding_groups, bus in buses],
        if has_any_simple_bids(inputs)
            sum(
                bidding_group_generation[blk, bg, bds, bus] for
                bds in 1:1:number_of_bg_valid_bidding_segments(inputs, bg)
                if bg in bidding_groups;
                init = 0.0,
            )
        else
            0.0
        end
        +
        if has_any_profile_bids(inputs)
            sum(
                bidding_group_generation_profile[blk, bg, prf, bus] for
                prf in 1:number_of_valid_profiles(inputs, bg)
                if bg in bidding_groups;
                init = 0.0,
            )
        else
            0.0
        end
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
        #                       = Σ(- MW offers)
        #
        # Example:
        #   - Factory A offers a elastic demand of 20 MW
        #   - Factory B offers a elastic demand of 30 MW
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
function link_offers_and_generation!(
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
function link_offers_and_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end
function link_offers_and_generation!(
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
