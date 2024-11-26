#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_correspondence_by_volume! end

"""
    virtual_reservoir_correspondence_by_volume!(
        model::SubproblemModel,
        inputs::Inputs,
        run_time_options::RunTimeOptions,
        ::Type{SubproblemBuild},
    )

Add the virtual reservoir correspondence by volume constraints to the model.
"""
function virtual_reservoir_correspondence_by_volume!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    number_of_segments = maximum_number_of_virtual_reservoir_bidding_segments(inputs)

    hydro_volume = get_model_object(model, :hydro_volume)
    virtual_reservoir_energy_stock = get_model_object(model, :virtual_reservoir_energy_stock)
    virtual_reservoir_generation = get_model_object(model, :virtual_reservoir_generation)

    @constraint(
        model.jump_model,
        virtual_reservoir_volume_balance[vr in virtual_reservoirs],
        sum(
            hydro_volume[end, h] * virtual_reservoir_water_to_energy_factors(inputs, vr)[h] for
            h in virtual_reservoir_hydro_unit_indices(inputs, vr)
        )
        ==
        sum(
            virtual_reservoir_energy_stock[vr, ao] -
            sum(virtual_reservoir_generation[vr, ao, seg] for seg in 1:number_of_segments) for
            ao in virtual_reservoir_asset_owner_indices(inputs, vr)
        )
    )

    return nothing
end

function virtual_reservoir_correspondence_by_volume!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function virtual_reservoir_correspondence_by_volume!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_correspondence_by_volume!(
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
