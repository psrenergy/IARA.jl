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
    placeholder_virtual_reservoir_total_available_energy = 0.0

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
        virtual_reservoir_total_available_energy
        in
        MOI.Parameter(placeholder_virtual_reservoir_total_available_energy)
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

    available_energy_parameter = get_model_object(model, :virtual_reservoir_total_available_energy)

    available_energy = virtual_reservoir_total_available_energy(
        inputs,
        run_time_options,
        simulation_period,
        simulation_trajectory,
        subscenario,
    )

    set_parameter_value(available_energy_parameter, available_energy)

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
