#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function battery_storage! end

function battery_storage!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    batteries = index_of_elements(inputs, Battery; run_time_options, filters = [is_existing])

    @variable(
        model.jump_model,
        battery_storage_state[bat in batteries],
        SDDP.State,
        initial_value = battery_initial_storage(inputs, bat),
        lower_bound = battery_min_storage(inputs, bat),
        upper_bound = battery_max_storage(inputs, bat),
    )

    battery_blocks = collect(1:number_of_blocks(inputs)+1)

    @variable(
        model.jump_model,
        battery_storage[b in battery_blocks, bat in batteries],
        lower_bound = battery_min_storage(inputs, bat),
        upper_bound = battery_max_storage(inputs, bat),
    )

    model.obj_exp = @expression(
        model.jump_model,
        model.obj_exp +
        money_to_thousand_money() * sum(
            battery_storage[block, bat] * battery_om_cost(inputs, bat)
            for block in blocks(inputs), bat in batteries
        ),
    )

    return nothing
end

function battery_storage!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function battery_storage!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    batteries = index_of_elements(inputs, Battery; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :battery_storage)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "battery_storage",
        dimensions = ["stage", "scenario", "block"],
        unit = "GWh",
        labels = battery_label(inputs)[batteries],
        run_time_options,
    )
    return nothing
end

function battery_storage!(
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

    battery_storage = simulation_results.data[:battery_storage]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = batteries,
        elements_to_write = existing_batteries,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "battery_storage",
        battery_storage.data;
        stage,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )

    return nothing
end
