#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function bus_voltage_angle! end

"""
    bus_voltage_angle!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the bus voltage angle variables to the model.
"""
function bus_voltage_angle!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    buses = index_of_elements(inputs, Bus)

    @variable(
        model.jump_model,
        bus_voltage_angle[b in subperiods(inputs), n in buses],
    )

    return nothing
end

function bus_voltage_angle!(
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

"""
    bus_voltage_angle!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output file to store the bus voltage angle variables' values.
    """
function bus_voltage_angle!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    buses = index_of_elements(inputs, Bus; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :bus_voltage_angle)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "bus_voltage_angle",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "rad",
        labels = bus_label(inputs)[buses],
        run_time_options,
    )
    return nothing
end

"""
    bus_voltage_angle!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the bus voltage angle variables' values to the output file.
    """
function bus_voltage_angle!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    bus_voltage_angle = simulation_results.data[:bus_voltage_angle]

    bus_voltage_angle_difference = bus_voltage_angle.data[:, :] .- bus_voltage_angle.data[:, 1]

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "bus_voltage_angle",
        bus_voltage_angle_difference;
        period,
        scenario,
        subscenario,
    )
    return nothing
end
