#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function kirchhoffs_voltage_law! end

function kirchhoffs_voltage_law!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    ac_branches = index_of_elements(inputs, Branch; filters = [is_existing, is_ac])

    # Model Variables
    bus_voltage_angle = get_model_object(model, :bus_voltage_angle)
    branch_flow = get_model_object(model, :branch_flow)

    # Constraints
    @constraint(
        model.jump_model,
        kirchhoffs_voltage_law[
            b in subperiods(inputs),
            l in ac_branches,
        ],
        -1 / branch_reactance(inputs, l) *
        (bus_voltage_angle[b, branch_bus_to(inputs, l)] - bus_voltage_angle[b, branch_bus_from(inputs, l)])
        ==
        branch_flow[b, l],
    )

    return nothing
end

function kirchhoffs_voltage_law!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function kirchhoffs_voltage_law!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function kirchhoffs_voltage_law!(
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
