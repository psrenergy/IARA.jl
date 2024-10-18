#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function thermal_generation! end

function thermal_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    thermal_plants =
        index_of_elements(inputs, ThermalPlant; run_time_options = run_time_options, filters = [is_existing])
    # generation in MWh, max generation in MW
    @variable(
        model.jump_model,
        thermal_generation[b in blocks(inputs), t in thermal_plants],
        lower_bound = 0.0,
        upper_bound = thermal_plant_max_generation(inputs, t) * block_duration_in_hours(inputs, b),
    )

    @expression(
        model.jump_model,
        thermal_total_om_cost,
        money_to_thousand_money() * sum(
            thermal_generation[b, t] * thermal_plant_om_cost(inputs, t)
            for b in blocks(inputs), t in thermal_plants
        ),
    ) # k$

    # Generation costs are used as a penalty in the clearing problem, with weight 1e-3
    if run_mode(inputs) == IARA.Configurations_RunMode.MARKET_CLEARING &&
       clearing_model_type(inputs, run_time_options) != IARA.Configurations_ClearingModelType.COST_BASED
        model.obj_exp = @expression(
            model.jump_model,
            model.obj_exp + thermal_total_om_cost / 1e3
        )
    else
        model.obj_exp = @expression(
            model.jump_model,
            model.obj_exp + thermal_total_om_cost
        )
    end

    return nothing
end

function thermal_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function thermal_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    thermals = index_of_elements(inputs, ThermalPlant; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :thermal_generation)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "thermal_generation",
        dimensions = ["stage", "scenario", "block"],
        unit = "GWh",
        labels = thermal_plant_label(inputs)[thermals],
        run_time_options,
    )
    return nothing
end

function thermal_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    thermal_plants = index_of_elements(inputs, ThermalPlant; run_time_options)
    existing_thermal_plants = index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing])

    thermal_generation = simulation_results.data[:thermal_generation]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = thermal_plants,
        elements_to_write = existing_thermal_plants,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "thermal_generation",
        thermal_generation.data;
        stage,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )

    return nothing
end
