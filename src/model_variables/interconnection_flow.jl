#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function interconnection_flow! end

"""
    interconnection_flow!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the DC flow variables to the model.
"""
function interconnection_flow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    interconnections = index_of_elements(inputs, Interconnection; filters = [is_existing])
    @variable(
        model.jump_model,
        interconnection_flow[b in subperiods(inputs), l in interconnections],
        lower_bound = -interconnection_capacity_from(inputs, l),
        upper_bound = interconnection_capacity_to(inputs, l),
    )

    return nothing
end

function interconnection_flow!(
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
    interconnection_flow!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize output file to store the DC flow variables' values.
"""
function interconnection_flow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    interconnections = index_of_elements(inputs, Interconnection; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :interconnection_flow)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "interconnection_flow",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "MW",
        labels = interconnection_label(inputs)[interconnections],
        run_time_options,
    )
    return nothing
end

"""
    interconnection_flow!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the DC flow variables' values to the output file.
"""
function interconnection_flow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    interconnections = index_of_elements(inputs, Interconnection; run_time_options)
    existing_interconnections = index_of_elements(inputs, Interconnection; run_time_options, filters = [is_existing])

    interconnection_flow = simulation_results.data[:interconnection_flow]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = interconnections,
        elements_to_write = existing_interconnections,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "interconnection_flow",
        interconnection_flow.data;
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
