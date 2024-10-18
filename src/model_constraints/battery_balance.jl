#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function battery_balance! end

function battery_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    batteries = index_of_elements(inputs, Battery; run_time_options, filters = [is_existing])

    # Model variables
    battery_generation = get_model_object(model, :battery_generation)
    battery_storage = get_model_object(model, :battery_storage)
    battery_storage_state = get_model_object(model, :battery_storage_state)

    # Constraints
    @constraint(
        model.jump_model,
        battery_balance[block in blocks(inputs), bat in batteries],
        battery_storage[block+1, bat] == battery_storage[block, bat] - battery_generation[block, bat]
    )

    @constraint(
        model.jump_model,
        battery_state_in[bat in batteries],
        battery_storage_state[bat].in == battery_storage[1, bat]
    )

    @constraint(
        model.jump_model,
        battery_state_out[bat in batteries],
        battery_storage_state[bat].out == battery_storage[end, bat]
    )

    return nothing
end

function battery_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function battery_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function battery_balance!(
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
