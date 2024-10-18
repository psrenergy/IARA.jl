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

function bidding_group_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    existing_hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])
    existing_thermal_plants = index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing])
    existing_renewable_plants = index_of_elements(inputs, RenewablePlant; run_time_options, filters = [is_existing])
    existing_batteries = index_of_elements(inputs, Battery; run_time_options, filters = [is_existing])
    blks = blocks(inputs)
    bid_segments = bidding_segments(inputs)

    # Model variables
    bidding_group_energy_offer = get_model_object(model, :bidding_group_energy_offer)
    hydro_generation = if any_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])
        get_model_object(model, :hydro_generation)
    end
    thermal_generation = if any_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing])
        get_model_object(model, :thermal_generation)
    end
    renewable_generation = if any_elements(inputs, RenewablePlant; run_time_options, filters = [is_existing])
        get_model_object(model, :renewable_generation)
    end
    battery_generation = if any_elements(inputs, Battery; run_time_options, filters = [is_existing])
        get_model_object(model, :battery_generation)
    end

    # Constraints
    @constraint(
        model.jump_model,
        bidding_group_balance[
            blk in blks,
            bg in bidding_groups,
            bds in 1:maximum_bid_segments(inputs, bg),
            bus in buses,
        ],
        bidding_group_energy_offer[blk, bg, bds, bus] ==
        sum(
            hydro_generation[blk, h]
            for h in existing_hydro_plants
            if hydro_plant_bidding_group_index(inputs, h) == bg
            &&
            hydro_plant_bus_index(inputs, h) == bus;
            init = 0.0,
        ) +
        sum(
            thermal_generation[blk, t]
            for t in existing_thermal_plants
            if thermal_plant_bidding_group_index(inputs, t) == bg
            &&
            thermal_plant_bus_index(inputs, t) == bus;
            init = 0.0,
        ) +
        sum(
            renewable_generation[blk, r]
            for r in existing_renewable_plants
            if renewable_plant_bidding_group_index(inputs, r) == bg
            &&
            renewable_plant_bus_index(inputs, r) == bus;
            init = 0.0,
        ) +
        sum(
            battery_generation[blk, bat]
            for bat in existing_batteries
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
        dimensions = ["stage", "scenario", "block", "bid_segment"],
        unit = "\$/MWh",
        labels,
        run_time_options,
    )

    return nothing
end

function bidding_group_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
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
        stage,
        scenario,
        subscenario,
        multiply_by = (-1) / money_to_thousand_money(),
    )

    return nothing
end
