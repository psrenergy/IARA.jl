#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_balance! end

function hydro_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    if hydro_balance_block_resolution(inputs) == Configurations_HydroBalanceBlockResolution.AGGREGATED_BLOCKS
        hydro_balance_aggregated_blocks(model, inputs, run_time_options)
    elseif hydro_balance_block_resolution(inputs) == Configurations_HydroBalanceBlockResolution.CHRONOLOGICAL_BLOCKS
        hydro_balance_chronological_blocks(model, inputs, run_time_options)
    else
        error("Hydro balance block resolution $(hydro_balance_block_resolution(inputs)) not implemented.")
    end

    return nothing
end

function hydro_balance_aggregated_blocks(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    existing_hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])
    hydro_plants_operating_with_reservoir =
        index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, operates_with_reservoir])

    # Model Variables
    hydro_turbining = get_model_object(model, :hydro_turbining)
    hydro_spillage = get_model_object(model, :hydro_spillage)
    hydro_volume = get_model_object(model, :hydro_volume)
    inflow_slack = get_model_object(model, :inflow_slack)

    # If we are solving a clearing problem, there is no state variable, and the previous volume is obtained
    # from the serialized results of the previous stage
    hydro_volume_state = if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        get_model_object(model, :hydro_volume_state)
    end
    hydro_previous_stage_volume = if clearing_has_volume_variables(inputs, run_time_options)
        get_model_object(model, :hydro_previous_stage_volume)
    end

    # Model parameters
    inflow = get_model_object(model, :inflow)

    @constraint(
        model.jump_model,
        hydro_balance[
            h in existing_hydro_plants,
        ],
        if operates_with_reservoir(inputs.collections.hydro_plant, h)
            hydro_volume[2, h]
        else
            0.0
        end
        ==
        if operates_with_reservoir(inputs.collections.hydro_plant, h)
            hydro_volume[1, h]
        else
            0.0
        end
        +
        sum(
            -
            hydro_turbining[b, h]
            -
            hydro_spillage[b, h]
            +
            sum(
                hydro_turbining[b, h_upstream] for
                h_upstream in index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing]) if
                hydro_plant_turbine_to(inputs, h_upstream) == h
            )
            +
            sum(
                hydro_spillage[b, h_upstream] for
                h_upstream in index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing]) if
                hydro_plant_spill_to(inputs, h_upstream) == h
            )
            +
            inflow_slack[b, h]
            +
            inflow[b, h]
            for b in blocks(inputs)
        )
    )

    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        @constraint(
            model.jump_model,
            hydro_state_in[h in hydro_plants_operating_with_reservoir],
            hydro_volume_state[h].in == hydro_volume[1, h]
        )

        @constraint(
            model.jump_model,
            hydro_state_out[h in hydro_plants_operating_with_reservoir],
            hydro_volume_state[h].out == hydro_volume[2, h]
        )
    elseif clearing_has_volume_variables(inputs, run_time_options)
        @constraint(
            model.jump_model,
            hydro_initial_state[h in hydro_plants_operating_with_reservoir],
            hydro_volume[1, h] == hydro_previous_stage_volume[h]
        )
    end

    return nothing
end

function hydro_balance_chronological_blocks(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    existing_hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])
    hydro_plants_operating_with_reservoir =
        index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, operates_with_reservoir])
    hydro_plants_operating_as_run_of_river =
        index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, operates_as_run_of_river])

    # Model Variables
    hydro_turbining = get_model_object(model, :hydro_turbining)
    hydro_spillage = get_model_object(model, :hydro_spillage)
    hydro_volume = get_model_object(model, :hydro_volume)
    inflow_slack = get_model_object(model, :inflow_slack)

    # If we are solving a clearing problem, there is no state variable, and the previous volume is obtained
    # from the serialized results of the previous stage
    hydro_volume_state = if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        get_model_object(model, :hydro_volume_state)
    end
    hydro_previous_stage_volume = if clearing_has_volume_variables(inputs, run_time_options)
        get_model_object(model, :hydro_previous_stage_volume)
    end

    # Model parameters
    inflow = get_model_object(model, :inflow)

    # Constraints
    # All variables are in [hm^3]
    @constraint(
        model.jump_model,
        hydro_balance[
            b in blocks(inputs),
            h in existing_hydro_plants,
        ],
        hydro_volume[b+1, h]
        ==
        hydro_volume[b, h]
        -
        hydro_turbining[b, h]
        -
        hydro_spillage[b, h]
        +
        sum(
            hydro_turbining[b, h_upstream] for
            h_upstream in existing_hydro_plants if
            hydro_plant_turbine_to(inputs, h_upstream) == h
        )
        +
        sum(
            hydro_spillage[b, h_upstream] for
            h_upstream in existing_hydro_plants if
            hydro_plant_spill_to(inputs, h_upstream) == h
        )
        +
        inflow_slack[b, h]
        +
        inflow[b, h]
    )

    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        @constraint(
            model.jump_model,
            hydro_state_in[h in hydro_plants_operating_with_reservoir],
            hydro_volume_state[h].in == hydro_volume[1, h]
        )

        @constraint(
            model.jump_model,
            hydro_state_out[h in hydro_plants_operating_with_reservoir],
            hydro_volume_state[h].out == hydro_volume[end, h]
        )
    elseif clearing_has_volume_variables(inputs, run_time_options)
        @constraint(
            model.jump_model,
            hydro_initial_state[h in hydro_plants_operating_with_reservoir],
            hydro_volume[1, h] == hydro_previous_stage_volume[h]
        )
    end

    @constraint(
        model.jump_model,
        hydro_plants_run_of_river_vivf[h in hydro_plants_operating_as_run_of_river],
        hydro_volume[1, h] == hydro_volume[end, h]
    )

    return nothing
end

function hydro_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function hydro_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydros = index_of_elements(inputs, HydroPlant; run_time_options)

    # The names water_marginal_cost and hydro_opportunity_cost are different
    # because the first is the constraint dual 
    # and the second is the actual output, which has some adjustments

    add_custom_recorder_to_query_from_subproblem_result!(
        outputs,
        :water_marginal_cost,
        constraint_dual_recorder(:hydro_balance),
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_opportunity_cost",
        dimensions = ["stage", "scenario", "block"],
        unit = "\$/MWh",
        labels = hydro_plant_label(inputs)[hydros],
        run_time_options,
    )

    return nothing
end

function hydro_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options)
    existing_hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])
    number_of_existing_hydro_plants = length(existing_hydro_plants)

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_plants,
        elements_to_write = existing_hydro_plants,
    )

    water_marginal_cost = simulation_results.data[:water_marginal_cost] * (-1)
    hydro_opportunity_cost = zeros(number_of_blocks(inputs), number_of_existing_hydro_plants)

    for (idx, h) in enumerate(existing_hydro_plants)
        if hydro_plant_production_factor(inputs, h) == 0
            continue
        end
        marginal_cost_to_opportunity_cost =
            m3_per_second_to_hm3_per_hour() / hydro_plant_production_factor(inputs, h) / money_to_thousand_money()
        if hydro_balance_block_resolution(inputs) == Configurations_HydroBalanceBlockResolution.CHRONOLOGICAL_BLOCKS
            for blk in blocks(inputs)
                hydro_opportunity_cost[blk, idx] = water_marginal_cost[blk, h] * marginal_cost_to_opportunity_cost
                downstream_idx = hydro_plant_turbine_to(inputs, h)
                if !is_null(downstream_idx) && downstream_idx in existing_hydro_plants
                    hydro_opportunity_cost[blk, idx] -=
                        water_marginal_cost[blk, downstream_idx] * marginal_cost_to_opportunity_cost
                end
            end
        elseif hydro_balance_block_resolution(inputs) == Configurations_HydroBalanceBlockResolution.AGGREGATED_BLOCKS
            for blk in blocks(inputs)
                hydro_opportunity_cost[blk, idx] = water_marginal_cost[h] * marginal_cost_to_opportunity_cost
                downstream_idx = hydro_plant_turbine_to(inputs, h)
                if !is_null(downstream_idx) && downstream_idx in existing_hydro_plants
                    hydro_opportunity_cost[blk, idx] -=
                        water_marginal_cost[downstream_idx] * marginal_cost_to_opportunity_cost
                end
            end
        else
            error("Hydro balance block resolution $(hydro_balance_block_resolution(inputs)) not implemented.")
        end
    end

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "hydro_opportunity_cost",
        hydro_opportunity_cost;
        stage,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
