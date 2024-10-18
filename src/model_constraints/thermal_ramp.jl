#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function thermal_ramp! end

function thermal_ramp!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    ramp_indexes =
        index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, has_ramp_constraints])

    # TODO: Check if necessary to divide by hours
    # Model Variables
    thermal_generation = get_model_object(model, :thermal_generation)

    # Ramp constraints
    @constraint(
        model.jump_model,
        thermal_ramp_up[
            b in 2:number_of_blocks(inputs),
            t in ramp_indexes,
        ],
        thermal_generation[b, t] / block_duration_in_hours(inputs, b)
        -
        thermal_generation[b-1, t] / block_duration_in_hours(inputs, b - 1)
        <=
        thermal_plant_max_ramp_up(inputs, t) * per_minute_to_per_hour()
        * (block_duration_in_hours(inputs, b) + block_duration_in_hours(inputs, b - 1)) / 2
    )

    @constraint(
        model.jump_model,
        thermal_ramp_down[
            b in 2:number_of_blocks(inputs),
            t in ramp_indexes,
        ],
        thermal_generation[b-1, t] / block_duration_in_hours(inputs, b - 1)
        -
        thermal_generation[b, t] / block_duration_in_hours(inputs, b) <=
        thermal_plant_max_ramp_down(inputs, t) * per_minute_to_per_hour()
        * (block_duration_in_hours(inputs, b) + block_duration_in_hours(inputs, b - 1)) / 2
    )

    # Initial conditions
    if model.stage == 1
        initial_condition_indexes =
            [t for t in ramp_indexes if !is_null(thermal_plant_generation_initial_condition(inputs, t))]

        @constraint(
            model.jump_model,
            thermal_ramp_up_initial[
                t in initial_condition_indexes
            ],
            thermal_generation[1, t] / block_duration_in_hours(inputs, 1)
            -
            thermal_plant_generation_initial_condition(inputs, t)
            <=
            thermal_plant_max_ramp_up(inputs, t) * per_minute_to_per_hour() * block_duration_in_hours(inputs, 1)
        )

        @constraint(
            model.jump_model,
            thermal_ramp_down_initial[
                t in initial_condition_indexes
            ],
            thermal_plant_generation_initial_condition(inputs, t)
            -
            thermal_generation[1, t] / block_duration_in_hours(inputs, 1)
            <=
            thermal_plant_max_ramp_down(inputs, t) * per_minute_to_per_hour() * block_duration_in_hours(inputs, 1)
        )
    end

    # Connect first block to last block
    if loop_blocks_for_thermal_constraints(inputs)
        @constraint(
            model.jump_model,
            thermal_ramp_up_last_block[
                t in ramp_indexes
            ],
            thermal_generation[1, t] / block_duration_in_hours(inputs, 1)
            -
            thermal_generation[end, t] / block_duration_in_hours(inputs, number_of_blocks(inputs))
            <=
            thermal_plant_max_ramp_up(inputs, t) * per_minute_to_per_hour()
            * (block_duration_in_hours(inputs, number_of_blocks(inputs)) + block_duration_in_hours(inputs, 1)) / 2
        )
        @constraint(
            model.jump_model,
            thermal_ramp_down_last_block[
                t in ramp_indexes
            ],
            thermal_generation[end, t] / block_duration_in_hours(inputs, number_of_blocks(inputs))
            -
            thermal_generation[1, t] / block_duration_in_hours(inputs, 1)
            <=
            thermal_plant_max_ramp_down(inputs, t) * per_minute_to_per_hour()
            * (block_duration_in_hours(inputs, number_of_blocks(inputs)) + block_duration_in_hours(inputs, 1)) / 2
        )
    end

    # TODO: Include initial condition and blocks connection to documentation
    return nothing
end

function thermal_ramp!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function thermal_ramp!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function thermal_ramp!(
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
