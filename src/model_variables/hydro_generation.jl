#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_generation! end

function hydro_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    existing_hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])
    existing_hydro_plants_with_min_outflow =
        index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, has_min_outflow])

    # Variables
    @variable(
        model.jump_model,
        hydro_turbining[b in blocks(inputs), h in existing_hydro_plants],
        lower_bound = 0.0,
        upper_bound =
            hydro_plant_max_available_turbining(inputs, h) *
            m3_per_second_to_hm3_per_hour() * block_duration_in_hours(inputs, b),
    )
    @variable(
        model.jump_model,
        hydro_spillage[b in blocks(inputs), h in existing_hydro_plants],
        lower_bound = 0.0,
    )
    @variable(
        model.jump_model,
        hydro_minimum_outflow_slack[
            blocks(inputs),
            existing_hydro_plants_with_min_outflow,
        ],
        lower_bound = 0.0,
    )

    # Expressions
    @expression(
        model.jump_model,
        hydro_generation[b in blocks(inputs), h in existing_hydro_plants],
        hydro_plant_production_factor(inputs, h) * hydro_turbining[b, h] / m3_per_second_to_hm3_per_hour()
    )

    # Objective
    @expression(
        model.jump_model,
        hydro_minimum_outflow_violation_cost_expression[
            b in blocks(inputs),
            h in existing_hydro_plants_with_min_outflow,
        ],
        hydro_minimum_outflow_slack[b, h] * hydro_minimum_outflow_violation_cost(inputs)
    )
    @expression(
        model.jump_model,
        hydro_spillage_penalty[b in blocks(inputs), h in existing_hydro_plants],
        hydro_spillage[b, h] * hydro_spillage_cost(inputs)
    )

    model.obj_exp +=
        money_to_thousand_money() * sum(
            hydro_minimum_outflow_violation_cost_expression[b, h] for b in blocks(inputs),
            h in existing_hydro_plants_with_min_outflow;
            init = 0.0,
        ) + money_to_thousand_money() * sum(hydro_spillage_penalty)

    @expression(
        model.jump_model,
        hydro_om_cost_expression[b in blocks(inputs), h in existing_hydro_plants],
        hydro_generation[b, h] * hydro_plant_om_cost(inputs, h)
    )

    # Generation costs are used as a penalty in the clearing problem, with weight 1e-3
    if run_mode(inputs) == IARA.Configurations_RunMode.MARKET_CLEARING
        model.obj_exp += money_to_thousand_money() * sum(hydro_om_cost_expression) / 1e3
    else
        model.obj_exp += money_to_thousand_money() * sum(hydro_om_cost_expression)
    end

    return nothing
end

function hydro_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function hydro_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydros = index_of_elements(inputs, HydroPlant; run_time_options)

    add_symbol_to_query_from_subproblem_result!(
        outputs,
        [
            :hydro_turbining,
            :hydro_spillage,
            :hydro_generation,
            :hydro_spillage_penalty,
        ],
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_turbining",
        dimensions = ["stage", "scenario", "block"],
        unit = "m3/s",
        labels = hydro_plant_label(inputs)[hydros],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_spillage",
        dimensions = ["stage", "scenario", "block"],
        unit = "m3/s",
        labels = hydro_plant_label(inputs)[hydros],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_generation",
        dimensions = ["stage", "scenario", "block"],
        unit = "GWh",
        labels = hydro_plant_label(inputs)[hydros],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_spillage_penalty",
        dimensions = ["stage", "scenario", "block"],
        unit = "\$",
        labels = hydro_plant_label(inputs)[hydros],
        run_time_options,
    )

    if any_elements(inputs, HydroPlant; run_time_options, filters = [has_min_outflow])
        add_symbol_to_query_from_subproblem_result!(
            outputs,
            [
                :hydro_minimum_outflow_slack,
                :hydro_minimum_outflow_violation_cost_expression,
            ],
        )

        hydro_plants_with_minimum_outflow = index_of_elements(
            inputs,
            HydroPlant;
            run_time_options,
            filters = [has_min_outflow],
        )

        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "hydro_minimum_outflow_slack",
            dimensions = ["stage", "scenario", "block"],
            unit = "m3/s",
            labels = hydro_plant_label(inputs)[hydro_plants_with_minimum_outflow],
            run_time_options,
        )

        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "hydro_minimum_outflow_violation_cost_expression",
            dimensions = ["stage", "scenario", "block"],
            unit = "\$",
            labels = hydro_plant_label(inputs)[hydro_plants_with_minimum_outflow],
            run_time_options,
        )
    end
    return nothing
end

function hydro_generation!(
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

    hydro_turbining = simulation_results.data[:hydro_turbining]
    hydro_spillage = simulation_results.data[:hydro_spillage]
    hydro_generation = simulation_results.data[:hydro_generation]
    hydro_spillage_penalty = simulation_results.data[:hydro_spillage_penalty]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_plants,
        elements_to_write = existing_hydro_plants,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "hydro_turbining",
        hydro_turbining.data;
        stage,
        scenario,
        subscenario,
        multiply_by = 1 / m3_per_second_to_hm3_per_hour(),
        divide_by_block_duration_in_hours = true,
        indices_of_elements_in_output,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "hydro_spillage",
        hydro_spillage.data;
        stage,
        scenario,
        subscenario,
        multiply_by = 1 / m3_per_second_to_hm3_per_hour(),
        divide_by_block_duration_in_hours = true,
        indices_of_elements_in_output,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "hydro_generation",
        hydro_generation.data;
        stage,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "hydro_spillage_penalty",
        hydro_spillage_penalty.data;
        stage,
        scenario,
        subscenario,
        multiply_by = 1 / m3_per_second_to_hm3_per_hour(),
        divide_by_block_duration_in_hours = true,
        indices_of_elements_in_output,
    )

    if any_elements(inputs, HydroPlant; run_time_options, filters = [has_min_outflow])
        hydro_plants_with_minimum_outflow = index_of_elements(
            inputs,
            HydroPlant;
            run_time_options,
            filters = [has_min_outflow],
        )

        existing_hydro_plants_with_min_outflow = index_of_elements(
            inputs,
            HydroPlant;
            run_time_options,
            filters = [is_existing, has_min_outflow],
        )

        hydro_minimum_outflow_slack = simulation_results.data[:hydro_minimum_outflow_slack]
        hydro_minimum_outflow_violation_cost = simulation_results.data[:hydro_minimum_outflow_violation_cost_expression]

        indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
            elements_in_output_file = hydro_plants_with_minimum_outflow,
            elements_to_write = existing_hydro_plants_with_min_outflow,
        )

        write_output_per_block!(
            outputs,
            inputs,
            run_time_options,
            "hydro_minimum_outflow_slack",
            hydro_minimum_outflow_slack.data;
            stage,
            scenario,
            subscenario,
            multiply_by = 1 / m3_per_second_to_hm3_per_hour(),
            divide_by_block_duration_in_hours = true,
            indices_of_elements_in_output,
        )

        write_output_per_block!(
            outputs,
            inputs,
            run_time_options,
            "hydro_minimum_outflow_violation_cost_expression",
            hydro_minimum_outflow_violation_cost.data;
            stage,
            scenario,
            subscenario,
            indices_of_elements_in_output,
        )
    end
    return nothing
end
