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
            virtual_reservoir_energy_stock_from_previous_stage(inputs, 1, 1)[vr][ao],
        ),
    )
    return nothing
end

function virtual_reservoir_energy_stock!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    hydro_plants = index_of_elements(inputs, HydroPlant)
    inflow_series = time_series_inflow(inputs, run_time_options, subscenario)
    inflow_as_volume = [
        sum(
            inflow_series[hydro_plant_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
            block_duration_in_hours(inputs, b) for b in blocks(inputs)
        ) for h in hydro_plants
    ]
    virtual_reservoir_energy_stock_at_beginning_of_stage =
        virtual_reservoir_energy_stock_from_previous_stage(inputs, model.stage, scenario)
    volume_at_beginning_of_stage = hydro_volume_from_previous_stage(inputs, model.stage, scenario)
    virtual_reservoir_energy_stock = get_model_object(model, :virtual_reservoir_energy_stock)
    for vr in virtual_reservoirs
        energy_arrival = additional_energy_from_inflows(inputs, vr, inflow_as_volume, volume_at_beginning_of_stage)
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                virtual_reservoir_energy_stock[vr, ao],
                virtual_reservoir_energy_stock_at_beginning_of_stage[vr][ao] +
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
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
