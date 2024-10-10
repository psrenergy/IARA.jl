#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function battery_generation! end

function battery_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    batteries = index_of_elements(inputs, Battery; run_time_options, filters = [is_existing])

    @variable(
        model.jump_model,
        battery_generation[block in blocks(inputs), bat in batteries],
        lower_bound = -battery_max_capacity(inputs, bat) * block_duration_in_hours(inputs, block),
        upper_bound = battery_max_capacity(inputs, bat) * block_duration_in_hours(inputs, block),
    )

    return nothing
end

function battery_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function battery_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    batteries = index_of_elements(inputs, Battery; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :battery_generation)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "battery_generation",
        dimensions = ["stage", "scenario", "block"],
        unit = "GWh",
        labels = battery_label(inputs)[batteries],
        run_time_options,
    )

    return nothing
end

function battery_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    batteries = index_of_elements(inputs, Battery; run_time_options)
    existing_batteries = index_of_elements(inputs, Battery; run_time_options, filters = [is_existing])

    battery_generation = simulation_results.data[:battery_generation]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = batteries,
        elements_to_write = existing_batteries,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "battery_generation",
        battery_generation.data;
        stage,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )

    return nothing
end
