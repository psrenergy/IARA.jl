#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bidding_group_balance! end

"""
    bidding_group_balance!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the bidding group balance constraints to the model.
"""
function bidding_group_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    existing_hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])
    existing_thermal_units = index_of_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing])
    existing_renewable_units = index_of_elements(inputs, RenewableUnit; run_time_options, filters = [is_existing])
    existing_battery_units = index_of_elements(inputs, BatteryUnit; run_time_options, filters = [is_existing])
    blks = subperiods(inputs)
    bid_segments = bidding_segments(inputs)

    # Model variables
    bidding_group_energy_offer = get_model_object(model, :bidding_group_energy_offer)
    hydro_generation = if any_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])
        get_model_object(model, :hydro_generation)
    end
    thermal_generation = if any_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing])
        get_model_object(model, :thermal_generation)
    end
    renewable_generation = if any_elements(inputs, RenewableUnit; run_time_options, filters = [is_existing])
        get_model_object(model, :renewable_generation)
    end
    battery_unit_generation = if any_elements(inputs, BatteryUnit; run_time_options, filters = [is_existing])
        get_model_object(model, :battery_unit_generation)
    end

    # Constraints
    @constraint(
        model.jump_model,
        bidding_group_balance[
            blk in blks,
            bg in bidding_groups,
            bds in bid_segments,
            bus in buses,
        ],
        bidding_group_energy_offer[blk, bg, bds, bus] ==
        sum(
            hydro_generation[blk, h]
            for h in existing_hydro_units
            if hydro_unit_bidding_group_index(inputs, h) == bg
            &&
            hydro_unit_bus_index(inputs, h) == bus;
            init = 0.0,
        ) +
        sum(
            thermal_generation[blk, t]
            for t in existing_thermal_units
            if thermal_unit_bidding_group_index(inputs, t) == bg
            &&
            thermal_unit_bus_index(inputs, t) == bus;
            init = 0.0,
        ) +
        sum(
            renewable_generation[blk, r]
            for r in existing_renewable_units
            if renewable_unit_bidding_group_index(inputs, r) == bg
            &&
            renewable_unit_bus_index(inputs, r) == bus;
            init = 0.0,
        ) +
        sum(
            battery_unit_generation[blk, bat]
            for bat in existing_battery_units
            if battery_bidding_group_index(inputs, bat) == bg
            &&
            battery_bus_index(inputs, bat) == bus;
            init = 0.0,
        )
    )

    return nothing
end

function bidding_group_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

"""
    bidding_group_balance!(outputs, inputs, run_time_options, ::Type{InitializeOutput})

Initialize the output files for:
- `bidding_group_price_offer`
"""
function bidding_group_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    add_custom_recorder_to_query_from_subproblem_result!(
        outputs,
        :bidding_group_price_offer,
        constraint_dual_recorder(:bidding_group_balance),
    )

    labels = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.bidding_group,
        inputs.collections.bus;
        index_getter = all_buses,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "bidding_group_price_offer",
        dimensions = ["period", "scenario", "subperiod", "bid_segment"],
        unit = "\$/MWh",
        labels,
        run_time_options,
    )

    return nothing
end

"""
    bidding_group_balance!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the bidding group results for:
- `bidding_group_price_offer`
"""
function bidding_group_balance!(
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
        "bidding_group_price_offer",
        simulation_results.data[:bidding_group_price_offer].data;
        period,
        scenario,
        subscenario,
        multiply_by = (-1) / money_to_thousand_money(),
    )

    return nothing
end
