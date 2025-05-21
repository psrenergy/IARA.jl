#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_energy_account! end

"""
    virtual_reservoir_energy_account!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the virtual reservoir energy account variables to the model.
"""
function virtual_reservoir_energy_account!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    @variable(
        model.jump_model,
        virtual_reservoir_energy_account[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
        ]
        in
        MOI.Parameter(
            virtual_reservoir_energy_account_from_previous_period(inputs, 1, 1)[vr][ao],
        ),
    )
    return nothing
end

"""
    virtual_reservoir_energy_account!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, scenario, subscenario, ::Type{SubproblemUpdate})

Update the virtual reservoir energy account variables in the model.
"""
function virtual_reservoir_energy_account!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    hydro_units = index_of_elements(inputs, HydroUnit)

    inflow_series = time_series_inflow(inputs, run_time_options; subscenario)

    virtual_reservoir_energy_account_at_beginning_of_period =
        virtual_reservoir_energy_account_from_previous_period(inputs, simulation_period, simulation_trajectory)
    volume_at_beginning_of_period = hydro_volume_from_previous_period(inputs, simulation_period, simulation_trajectory)

    vr_energy_arrival, _ = energy_from_inflows(inputs, inflow_series, volume_at_beginning_of_period)

    virtual_reservoir_energy_account = get_model_object(model, :virtual_reservoir_energy_account)
    for vr in virtual_reservoirs
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                virtual_reservoir_energy_account[vr, ao],
                virtual_reservoir_energy_account_at_beginning_of_period[vr][ao] +
                vr_energy_arrival[vr] * virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao),
            )
        end
    end

    return nothing
end

function virtual_reservoir_energy_account!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_energy_account!(
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
