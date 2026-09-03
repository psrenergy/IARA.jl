#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_total_generation! end

"""
    virtual_reservoir_total_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Virtual reservoir total generation variable and parameter initialization for the reference curve model.
"""
function virtual_reservoir_total_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    placeholder_virtual_reservoir_reference_multiplier = 0.0
    placeholder_virtual_reservoir_available_energy = 0.0

    # Variables
    @variable(
        model.jump_model,
        virtual_reservoir_total_generation[
            vr in virtual_reservoirs,
        ],
    ) # MWh

    # Parameters
    @variable(
        model.jump_model,
        virtual_reservoir_reference_multiplier
        in
        MOI.Parameter(placeholder_virtual_reservoir_reference_multiplier)
    ) # MWh
    @variable(
        model.jump_model,
        virtual_reservoir_available_energy[
            vr in virtual_reservoirs,
        ]
        in
        MOI.Parameter(placeholder_virtual_reservoir_available_energy)
    ) # MWh

    return nothing
end

function virtual_reservoir_total_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    # The virtual_reservoir_reference_multiplier is not dependent on period, scenario, or subscenario, so it is not updated here. 
    # To see how the param is updated at each iteration, see the "update_virtual_reservoir_reference_multiplier!" 
    # function in the "hydro_supply_reference_curve_utils.jl" file.

    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    virtual_reservoir_available_energy = get_model_object(model, :virtual_reservoir_available_energy)

    # Calculate total stored energy
    total_stored_energy = virtual_reservoir_stored_energy(
        inputs,
        run_time_options,
        simulation_period,
        simulation_trajectory,
        subscenario,
    )

    # Calculate maximum turbinable energy
    maximum_turbinable_energy = [
        sum(
            hydro_unit_max_available_turbining(inputs, h) * subperiod_duration_in_hours(inputs, b) *
            hydro_unit_production_factor(inputs, h)
            for b in subperiods(inputs), h in virtual_reservoir_hydro_unit_indices(inputs, vr)
        ) for vr in virtual_reservoirs
    ]

    # Calculate available energy for each virtual reservoir
    available_energy = [min(total_stored_energy[vr], maximum_turbinable_energy[vr]) for vr in virtual_reservoirs]

    # Total demand energy of the period. demand_mw_to_gwh returns GWh, while the energies
    # above are in MWh.
    demand_units = index_of_elements(inputs, DemandUnit; filters = [is_existing])
    demand_series = time_series_demand(inputs, run_time_options; subscenario)
    total_demand_energy =
        sum(
            demand_mw_to_gwh(inputs, demand_series[d, b], d, b)
            for b in subperiods(inputs), d in demand_units;
            init = 0.0,
        ) / MW_to_GW()

    # A curve wider than the demand prices quantities the market cannot absorb. Scaling keeps each
    # reservoir's share; the zero check avoids zeroing the curve when there is no demand.
    if total_demand_energy > 0 && sum(available_energy) > total_demand_energy
        available_energy .*= total_demand_energy / sum(available_energy)
    end

    for vr in virtual_reservoirs
        set_parameter_value(virtual_reservoir_available_energy[vr], available_energy[vr])
    end

    return nothing
end

function virtual_reservoir_total_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_total_generation!(
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
