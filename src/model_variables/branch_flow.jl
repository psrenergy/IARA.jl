#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function branch_flow! end

"""
    branch_flow!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the branch flow variables to the model.
"""
function branch_flow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    branches = index_of_elements(inputs, Branch; filters = [is_existing])

    @variable(
        model.jump_model,
        branch_flow[b in subperiods(inputs), l in branches],
        lower_bound = -branch_capacity(inputs, l),
        upper_bound = branch_capacity(inputs, l),
    )

    return nothing
end

function branch_flow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

"""
    branch_flow!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output file to store the branch flow variables' values.
"""
function branch_flow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    branches = index_of_elements(inputs, Branch; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :branch_flow)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "branch_flow",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "MW",
        labels = branch_label(inputs)[branches],
        run_time_options,
    )
    return nothing
end

"""
    branch_flow!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the branch flow variables' values to the output file.
"""
function branch_flow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    branches = index_of_elements(inputs, Branch; run_time_options)
    existing_branches = index_of_elements(inputs, Branch; run_time_options, filters = [is_existing])

    branch_flow = simulation_results.data[:branch_flow]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = branches,
        elements_to_write = existing_branches,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "branch_flow",
        branch_flow.data;
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
