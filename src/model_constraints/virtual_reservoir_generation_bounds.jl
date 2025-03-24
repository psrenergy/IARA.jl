#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_generation_bounds! end

"""
    virtual_reservoir_generation_bounds!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the virtual reservoir generation bounds constraints to the model.
"""
function virtual_reservoir_generation_bounds!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    # Model variables
    virtual_reservoir_generation = get_model_object(model, :virtual_reservoir_generation)

    # Model parameters
    virtual_reservoir_quantity_offer = get_model_object(model, :virtual_reservoir_quantity_offer)
    virtual_reservoir_energy_stock = get_model_object(model, :virtual_reservoir_energy_stock)
    valid_segments = get_maximum_valid_virtual_reservoir_segments(inputs)

    # Model constraints
    @constraint(
        model.jump_model,
        virtual_reservoir_generation_bound_by_offer[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
            seg in 1:valid_segments[vr],
        ],
        virtual_reservoir_generation[vr, ao, seg] <=
        virtual_reservoir_quantity_offer[vr, ao, seg]
    )

    @constraint(
        model.jump_model,
        virtual_reservoir_generation_bound_by_availability[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
        ],
        sum(virtual_reservoir_generation[vr, ao, seg] for seg in 1:valid_segments[vr]) <=
        virtual_reservoir_energy_stock[vr, ao]
    )
    return nothing
end

function virtual_reservoir_generation_bounds!(
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

function virtual_reservoir_generation_bounds!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_generation_bounds!(
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
