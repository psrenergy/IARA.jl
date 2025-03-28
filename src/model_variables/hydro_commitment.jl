#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_commitment! end

"""
    hydro_commitment!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the hydro unit commitment variables to the model.
"""
function hydro_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    commitment_hydro_units =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, has_commitment])

    @variable(
        model.jump_model,
        hydro_commitment[
            b in subperiods(inputs),
            h in commitment_hydro_units,
        ],
        binary = true,
    )

    if use_binary_variables(inputs, run_time_options)
        add_symbol_to_integer_variables_list!(run_time_options, :hydro_commitment)
    end

    return nothing
end

function hydro_commitment!(
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
    hydro_commitment!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize output file to store the hydro unit commitment variables' values.
"""
function hydro_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydro_units_with_commitment = index_of_elements(inputs, HydroUnit; run_time_options, filters = [has_commitment])

    if run_time_options.clearing_model_subproblem != RunTime_ClearingSubproblem.EX_POST_COMMERCIAL
        add_symbol_to_query_from_subproblem_result!(outputs, [:hydro_commitment])
        if use_binary_variables(inputs, run_time_options)
            add_symbol_to_serialize!(outputs, :hydro_commitment)
        end
    end

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_commitment",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "-",
        labels = hydro_unit_label(inputs)[hydro_units_with_commitment],
        run_time_options,
    )
    return nothing
end

"""
    hydro_commitment!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the hydro unit commitment variables' values to the output file.
"""
function hydro_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    hydro_units_with_commitment = index_of_elements(inputs, HydroUnit; run_time_options, filters = [has_commitment])
    existing_hydro_units_with_commitment =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, has_commitment])

    hydro_commitment = simulation_results.data[:hydro_commitment]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_units_with_commitment,
        elements_to_write = existing_hydro_units_with_commitment,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "hydro_commitment",
        hydro_commitment.data;
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
