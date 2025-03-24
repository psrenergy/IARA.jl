#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_generation_bound_by_commitment! end

"""
    hydro_generation_bound_by_commitment!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the hydro generation bound by commitment constraints to the model.
"""
function hydro_generation_bound_by_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    commitment_hydro_units =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, has_commitment])

    # Model Variables
    hydro_generation = get_model_object(model, :hydro_generation)
    hydro_commitment = get_model_object(model, :hydro_commitment)

    # Constraints
    @constraint(
        model.jump_model,
        hydro_generation_lower_bound[
            b in subperiods(inputs),
            h in commitment_hydro_units,
        ],
        hydro_generation[b, h] >=
        hydro_unit_min_generation(inputs, h) * hydro_commitment[b, h] * subperiod_duration_in_hours(inputs, b)
    )

    @constraint(
        model.jump_model,
        hydro_generation_upper_bound[
            b in subperiods(inputs),
            h in commitment_hydro_units,
        ],
        hydro_generation[b, h] <=
        hydro_unit_max_generation(inputs, h) * hydro_commitment[b, h] * subperiod_duration_in_hours(inputs, b)
    )
    return nothing
end

function hydro_generation_bound_by_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function hydro_generation_bound_by_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function hydro_generation_bound_by_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
