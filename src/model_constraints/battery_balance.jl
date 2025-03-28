#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function battery_unit_balance! end

"""
    battery_unit_balance!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the battery unit balance constraints to the model.
"""
function battery_unit_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    battery_units = index_of_elements(inputs, BatteryUnit; run_time_options, filters = [is_existing])

    # Model variables
    battery_unit_generation = get_model_object(model, :battery_unit_generation)
    battery_unit_storage = get_model_object(model, :battery_unit_storage)
    battery_unit_storage_state = get_model_object(model, :battery_unit_storage_state)

    # Constraints
    @constraint(
        model.jump_model,
        battery_unit_balance[subperiod in subperiods(inputs), bat in battery_units],
        battery_unit_storage[subperiod+1, bat] ==
        battery_unit_storage[subperiod, bat] - battery_unit_generation[subperiod, bat]
    )

    @constraint(
        model.jump_model,
        battery_unit_state_in[bat in battery_units],
        battery_unit_storage_state[bat].in == battery_unit_storage[1, bat]
    )

    @constraint(
        model.jump_model,
        battery_unit_state_out[bat in battery_units],
        battery_unit_storage_state[bat].out == battery_unit_storage[end, bat]
    )

    return nothing
end

function battery_unit_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function battery_unit_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function battery_unit_balance!(
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
