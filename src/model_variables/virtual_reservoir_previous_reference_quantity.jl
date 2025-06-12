#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_previous_reference_quantity! end

"""
    virtual_reservoir_previous_reference_quantity!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Virtual reservoir total generation variable and parameter initialization for the reference curve model.
"""
function virtual_reservoir_previous_reference_quantity!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    placeholder_virtual_reservoir_previous_reference_quantity = 0.0

    # Parameters
    @variable(
        model.jump_model,
        virtual_reservoir_previous_reference_quantity[vr in virtual_reservoirs]
        in
        MOI.Parameter(placeholder_virtual_reservoir_previous_reference_quantity)
    ) # MWh

    return nothing
end

function virtual_reservoir_previous_reference_quantity!(
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

    virtual_reservoir_previous_reference_quantity = get_model_object(
        model,
        :virtual_reservoir_previous_reference_quantity,
    )

    # Quantity from previous iteration
    reference_quantity, reference_price =
        read_serialized_reference_curve(inputs, simulation_period, simulation_trajectory)
    sum_of_previous_reference_curve_quantities = sum_previous_reference_curve_quantities(
        inputs,
        reference_quantity,
    )

    # If the reference curve is complete, this constraint is not needed
    if sum_of_previous_reference_curve_quantities == virtual_reservoir_stored_energy(
        inputs,
        run_time_options,
        simulation_period,
        simulation_trajectory,
        subscenario,
    )
        sum_of_previous_reference_curve_quantities = 0.0
    end

    for vr in virtual_reservoirs
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            virtual_reservoir_previous_reference_quantity[vr],
            sum_of_previous_reference_curve_quantities[vr],
        )
    end

    return nothing
end

function virtual_reservoir_previous_reference_quantity!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_previous_reference_quantity!(
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
