#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function battery_reserve_generation! end

function battery_reserve_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    reserves = index_of_elements(inputs, Reserve)
    batteries = index_of_elements(inputs, Battery; filters = [is_existing])

    # Model Variables
    reserve_generation_in_battery = get_model_object(model, :reserve_generation_in_battery)
    battery_generation = get_model_object(model, :battery_generation)
    battery_storage = get_model_object(model, :battery_storage)

    @constraint(
        model.jump_model,
        battery_generation_and_reserve_upper_bound[
            b in blocks(inputs),
            ba in batteries,
        ],
        battery_generation[b, ba] +
        sum(
            reserve_generation_in_battery[b, r, ba]
            for r in reserves
            if ba in reserve_battery_indices(inputs, r) && reserve_has_direction_up(inputs, r)
        )
        <=
        battery_max_capacity(inputs, ba) * block_duration_in_hours(inputs, b)
    )

    @constraint(
        model.jump_model,
        battery_generation_and_reserve_lower_bound[
            b in blocks(inputs),
            ba in batteries,
        ],
        battery_generation[b, ba] -
        sum(
            reserve_generation_in_battery[b, r, ba]
            for r in reserves
            if ba in reserve_battery_indices(inputs, r) && reserve_has_direction_down(inputs, r)
        )
        >=
        -battery_max_capacity(inputs, ba) * block_duration_in_hours(inputs, b)
    )

    @constraint(
        model.jump_model,
        storage_availability_for_battery_reserve_up[
            b in blocks(inputs),
            ba in batteries,
        ],
        battery_storage[b, ba] -
        battery_generation[b, ba] -
        sum(
            reserve_generation_in_battery[b, r, ba]
            for r in reserves
            if ba in reserve_battery_indices(inputs, r) && reserve_has_direction_up(inputs, r)
        )
        >=
        battery_min_storage(inputs, ba)
    )

    @constraint(
        model.jump_model,
        storage_availability_for_battery_reserve_down[
            b in blocks(inputs),
            ba in batteries,
        ],
        battery_storage[b, ba] - battery_generation[b, ba] +
        sum(
            reserve_generation_in_battery[b, r, ba]
            for r in reserves
            if ba in reserve_battery_indices(inputs, r) && reserve_has_direction_down(inputs, r)
        )
        <=
        battery_max_storage(inputs, ba)
    )

    return nothing
end

function battery_reserve_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function battery_reserve_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function battery_reserve_generation!(
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
