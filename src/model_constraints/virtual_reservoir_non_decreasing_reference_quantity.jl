#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_non_decreasing_reference_quantity! end

"""
    virtual_reservoir_non_decreasing_reference_quantity!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Constraint ensuring the reference quantity for each virtual reservoir does not decrease at each iteration.
"""
function virtual_reservoir_non_decreasing_reference_quantity!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    # Model variables
    virtual_reservoir_total_generation = get_model_object(model, :virtual_reservoir_total_generation)
    # Model parameters
    virtual_reservoir_previous_reference_quantity = get_model_object(
        model,
        :virtual_reservoir_previous_reference_quantity,
    )

    # Model constraints
    @constraint(
        model.jump_model,
        virtual_reservoir_non_decreasing_reference_quantity[vr in virtual_reservoirs],
        virtual_reservoir_total_generation[vr] >= virtual_reservoir_previous_reference_quantity[vr]
    )

    return nothing
end

function virtual_reservoir_non_decreasing_reference_quantity!(
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

function virtual_reservoir_non_decreasing_reference_quantity!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_non_decreasing_reference_quantity!(
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
