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

function hydro_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    commitment_hydro_plants =
        index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, has_commitment])

    if use_binary_variables(inputs)
        @variable(
            model.jump_model,
            hydro_commitment[
                b in blocks(inputs),
                h in commitment_hydro_plants,
            ],
            binary = true,
        )
    else
        @variable(
            model.jump_model,
            hydro_commitment[
                b in blocks(inputs),
                h in commitment_hydro_plants,
            ],
            lower_bound = 0.0,
            upper_bound = 1.0,
        )
    end

    return nothing
end

function hydro_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function hydro_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydro_plants_with_commitment = index_of_elements(inputs, HydroPlant; run_time_options, filters = [has_commitment])

    add_symbol_to_query_from_subproblem_result!(outputs, [:hydro_commitment])

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_commitment",
        dimensions = ["stage", "scenario", "block"],
        unit = "-",
        labels = hydro_plant_label(inputs)[hydro_plants_with_commitment],
        run_time_options,
    )
    return nothing
end

function hydro_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    hydro_plants_with_commitment = index_of_elements(inputs, HydroPlant; run_time_options, filters = [has_commitment])
    existing_hydro_plants_with_commitment =
        index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, has_commitment])

    hydro_commitment = simulation_results.data[:hydro_commitment]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_plants_with_commitment,
        elements_to_write = existing_hydro_plants_with_commitment,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "hydro_commitment",
        hydro_commitment.data;
        stage,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
