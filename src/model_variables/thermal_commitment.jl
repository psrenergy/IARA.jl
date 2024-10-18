#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function thermal_commitment! end

function thermal_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    commitment_indexes =
        index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, has_commitment])

    @variable(
        model.jump_model,
        thermal_commitment[
            b in blocks(inputs),
            t in commitment_indexes,
        ],
        binary = true,
    )

    if use_binary_variables(inputs)
        add_symbol_to_integer_variables_list!(run_time_options, :thermal_commitment)
    end

    @variable(
        model.jump_model,
        thermal_startup[b in blocks(inputs), t in commitment_indexes],
        lower_bound = 0.0,
        upper_bound = 1.0,
    )

    @variable(
        model.jump_model,
        thermal_shutdown[b in blocks(inputs), t in commitment_indexes],
        lower_bound = 0.0,
        upper_bound = 1.0,
    )

    if loop_blocks_for_thermal_constraints(inputs)
        # Add fictitious startup and shutdown variables to connect the last block to the first block
        @variable(
            model.jump_model,
            thermal_startup_loop[t in commitment_indexes],
            lower_bound = 0.0,
            upper_bound = 1.0,
        )
        @variable(
            model.jump_model,
            thermal_shutdown_loop[t in commitment_indexes],
            lower_bound = 0.0,
            upper_bound = 1.0,
        )
    end

    @expression(
        model.jump_model,
        thermal_startup_cost[b in blocks(inputs), t in commitment_indexes],
        thermal_startup[b, t] * thermal_plant_startup_cost(inputs, t),
    )

    @expression(
        model.jump_model,
        thermal_shutdown_cost[b in blocks(inputs), t in commitment_indexes],
        thermal_shutdown[b, t] * thermal_plant_shutdown_cost(inputs, t),
    )

    model.obj_exp +=
        sum(thermal_startup_cost) * money_to_thousand_money() + sum(thermal_shutdown_cost) * money_to_thousand_money()

    return nothing
end

function thermal_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function thermal_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    thermal_plants_with_commitment = index_of_elements(
        inputs,
        ThermalPlant;
        run_time_options,
        filters = [has_commitment],
    )

    if run_time_options.clearing_model_procedure != RunTime_ClearingProcedure.EX_POST_COMMERCIAL
        add_symbol_to_query_from_subproblem_result!(outputs, :thermal_commitment)
        if use_binary_variables(inputs)
            add_symbol_to_serialize!(outputs, :thermal_commitment)
        end
    end

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "thermal_commitment",
        dimensions = ["stage", "scenario", "block"],
        unit = "-",
        labels = thermal_plant_label(inputs)[thermal_plants_with_commitment],
        run_time_options,
    )
    return nothing
end

function thermal_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    thermal_plants_with_commitment = index_of_elements(
        inputs,
        ThermalPlant;
        run_time_options,
        filters = [has_commitment],
    )
    existing_thermal_plants_with_commitment = index_of_elements(
        inputs,
        ThermalPlant;
        run_time_options,
        filters = [is_existing, has_commitment],
    )

    thermal_commitment = simulation_results.data[:thermal_commitment]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = thermal_plants_with_commitment,
        elements_to_write = existing_thermal_plants_with_commitment,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "thermal_commitment",
        thermal_commitment.data;
        stage,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
