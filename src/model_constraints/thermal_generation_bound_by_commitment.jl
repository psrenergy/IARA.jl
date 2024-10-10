#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function thermal_generation_bound_by_commitment! end

function thermal_generation_bound_by_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    commitment_thermal_plants =
        index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, has_commitment])
    # Model Variables
    thermal_generation = get_model_object(model, :thermal_generation)
    thermal_commitment = get_model_object(model, :thermal_commitment)

    # Constraints
    @constraint(
        model.jump_model,
        thermal_generation_lower_bound[
            b in blocks(inputs),
            t in commitment_thermal_plants,
        ],
        thermal_generation[b, t] >=
        thermal_plant_min_generation(inputs, t) * thermal_commitment[b, t] * block_duration_in_hours(inputs, b),
    )
    @constraint(
        model.jump_model,
        thermal_generation_upper_bound[
            b in blocks(inputs),
            t in commitment_thermal_plants,
        ],
        thermal_generation[b, t] <=
        thermal_plant_max_generation(inputs, t) * thermal_commitment[b, t] * block_duration_in_hours(inputs, b),
    )

    return nothing
end

function thermal_generation_bound_by_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function thermal_generation_bound_by_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function thermal_generation_bound_by_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
