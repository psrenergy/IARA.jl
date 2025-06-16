#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_total_generation_correspondence! end

"""
    virtual_reservoir_total_generation_correspondence!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the virtual reservoir correspondence by generation constraints to the model.
"""
function virtual_reservoir_total_generation_correspondence!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    number_of_virtual_reservoirs = number_of_elements(inputs, VirtualReservoir)

    # Model variables
    hydro_generation = get_model_object(model, :hydro_generation)

    # Model expression
    virtual_reservoir_total_generation = get_model_object(model, :virtual_reservoir_total_generation)

    # Model constraints
    @constraint(
        model.jump_model,
        virtual_reservoir_total_generation_balance[vr in 1:number_of_virtual_reservoirs],
        sum(
            hydro_generation[b, h]
            for b in subperiods(inputs), h in virtual_reservoir_hydro_unit_indices(inputs, vr)
        ) == virtual_reservoir_total_generation[vr]
    )

    return nothing
end

function virtual_reservoir_total_generation_correspondence!(
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

function virtual_reservoir_total_generation_correspondence!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_total_generation_correspondence!(
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
