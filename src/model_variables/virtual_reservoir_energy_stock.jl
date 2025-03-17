#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_energy_stock! end

"""
    virtual_reservoir_energy_stock!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the virtual reservoir energy stock variables to the model.
"""
function virtual_reservoir_energy_stock!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    @variable(
        model.jump_model,
        virtual_reservoir_energy_stock[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
        ]
        in
        MOI.Parameter(
            virtual_reservoir_energy_stock_from_previous_period(inputs, 1, 1)[vr][ao],
        ),
    )
    return nothing
end

"""
    virtual_reservoir_energy_stock!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, scenario, subscenario, ::Type{SubproblemUpdate})

Update the virtual reservoir energy stock variables in the model.
"""
function virtual_reservoir_energy_stock!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    hydro_units = index_of_elements(inputs, HydroUnit)
    inflow_series = time_series_inflow(inputs, run_time_options; subscenario)
    inflow_as_volume = [
        sum(
            inflow_series[hydro_unit_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
            subperiod_duration_in_hours(inputs, b) for b in subperiods(inputs)
        ) for h in hydro_units
    ]
    virtual_reservoir_energy_stock_at_beginning_of_period =
        virtual_reservoir_energy_stock_from_previous_period(inputs, model.period, scenario)
    volume_at_beginning_of_period = hydro_volume_from_previous_period(inputs, model.period, scenario)
    energy_arrival = additional_energy_from_inflows(inputs, inflow_as_volume, volume_at_beginning_of_period)
    virtual_reservoir_energy_stock = get_model_object(model, :virtual_reservoir_energy_stock)
    for vr in virtual_reservoirs
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                virtual_reservoir_energy_stock[vr, ao],
                virtual_reservoir_energy_stock_at_beginning_of_period[vr][ao] +
                energy_arrival[vr] * virtual_reservoir_asset_owners_inflow_allocation(inputs, vr, ao),
            )
        end
    end

    return nothing
end

function virtual_reservoir_energy_stock!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_energy_stock!(
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
