#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function dc_flow! end

function dc_flow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    dc_lines = index_of_elements(inputs, DCLine; filters = [is_existing])
    @variable(
        model.jump_model,
        dc_flow[b in blocks(inputs), l in dc_lines],
        lower_bound = -dc_line_capacity_from(inputs, l),
        upper_bound = dc_line_capacity_to(inputs, l),
    )

    return nothing
end

function dc_flow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function dc_flow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    dc_lines = index_of_elements(inputs, DCLine; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :dc_flow)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "dc_flow",
        dimensions = ["stage", "scenario", "block"],
        unit = "MW",
        labels = dc_line_label(inputs)[dc_lines],
        run_time_options,
    )
    return nothing
end

function dc_flow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    dc_lines = index_of_elements(inputs, DCLine; run_time_options)
    existing_dc_lines = index_of_elements(inputs, DCLine; run_time_options, filters = [is_existing])

    dc_flow = simulation_results.data[:dc_flow]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = dc_lines,
        elements_to_write = existing_dc_lines,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "dc_flow",
        dc_flow.data;
        stage,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
