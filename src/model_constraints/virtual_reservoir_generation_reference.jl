#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_generation_reference! end

"""
    virtual_reservoir_generation_reference!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Constraint matching virtual reservoir generation to the input reference generation for the reference curve model.
"""
function virtual_reservoir_generation_reference!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    # Model variables
    virtual_reservoir_total_generation = get_model_object(model, :virtual_reservoir_total_generation)

    # Model parameters
    virtual_reservoir_reference_multiplier = get_model_object(model, :virtual_reservoir_reference_multiplier)
    virtual_reservoir_available_energy = get_model_object(model, :virtual_reservoir_available_energy)

    # Model constraints
    @constraint(
        model.jump_model,
        virtual_reservoir_generation_reference,
        sum(virtual_reservoir_total_generation)
        ==
        virtual_reservoir_reference_multiplier * sum(virtual_reservoir_available_energy)
    )

    return nothing
end

function virtual_reservoir_generation_reference!(
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

function virtual_reservoir_generation_reference!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_generation_reference!(
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
