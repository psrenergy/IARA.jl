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
    hydro_units = index_of_elements(inputs, HydroUnit; filters = [is_existing])
    thermal_units = index_of_elements(inputs, ThermalUnit; filters = [is_existing])
    renewable_units = index_of_elements(inputs, RenewableUnit; filters = [is_existing])
    battery_units = index_of_elements(inputs, BatteryUnit; filters = [is_existing])
    hydro_generation = if any_elements(inputs, HydroUnit; filters = [is_existing])
        get_model_object(model, :hydro_generation)
    end
    thermal_generation = if any_elements(inputs, ThermalUnit; filters = [is_existing])
        get_model_object(model, :thermal_generation)
    end
    renewable_generation = if any_elements(inputs, RenewableUnit; filters = [is_existing])
        get_model_object(model, :renewable_generation)
    end
    battery_unit_generation = if any_elements(inputs, BatteryUnit; filters = [is_existing])
        get_model_object(model, :battery_unit_generation)
    end
    # Offer variables
    all_bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    independent_bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_independent_bids])
    profile_bidding_groups =
        index_of_elements(inputs, BiddingGroup; run_time_options, filters = [has_profile_bids])
    if any_elements(inputs, BiddingGroup; filters = [has_profile_bids])
        bidding_group_generation_profile = get_model_object(model, :bidding_group_generation_profile)
    end
    if any_elements(inputs, BiddingGroup; filters = [has_independent_bids])
        bidding_group_generation = get_model_object(model, :bidding_group_generation)
    end
    @constraint(
        model.jump_model,
        link_offers_and_generation[blk in blks, bg in all_bidding_groups, bus in buses],
        sum(
            bidding_group_generation[blk, bg, bds, bus] for
            bds in 1:maximum_bid_segments(inputs, bg)
            if bg in independent_bidding_groups;
            init = 0.0,
        ) +
        sum(
            bidding_group_generation_profile[blk, bg, prf, bus] for
            prf in 1:maximum_profiles(inputs, bg)
            if bg in profile_bidding_groups;
            init = 0.0,
        ) ==
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
    )
    return nothing
end
function link_offers_and_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
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
