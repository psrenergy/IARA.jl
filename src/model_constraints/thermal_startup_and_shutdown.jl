#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function thermal_startup_and_shutdown! end

function thermal_startup_and_shutdown!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    commitment_indexes =
        index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, has_commitment])
    max_startup_indexes = [t for t in commitment_indexes if !is_null(thermal_plant_max_startups(inputs, t))]
    max_shutdown_indexes = [t for t in commitment_indexes if !is_null(thermal_plant_max_shutdowns(inputs, t))]

    # Model Variables
    thermal_commitment = get_model_object(model, :thermal_commitment)
    thermal_startup = get_model_object(model, :thermal_startup)
    thermal_shutdown = get_model_object(model, :thermal_shutdown)

    # Startup and shutdown definition
    @constraint(
        model.jump_model,
        thermal_startup_and_shutdown[
            b in 2:number_of_blocks(inputs),
            t in commitment_indexes,
        ],
        thermal_startup[b, t] - thermal_shutdown[b, t] ==
        thermal_commitment[b, t] - thermal_commitment[b-1, t]
    )
    @constraint(
        model.jump_model,
        thermal_commitment_is_on[
            b in 2:number_of_blocks(inputs),
            t in commitment_indexes,
        ],
        thermal_startup[b, t] + thermal_shutdown[b, t] <=
        thermal_commitment[b, t] + thermal_commitment[b-1, t]
    )
    @constraint(
        model.jump_model,
        thermal_commitment_is_off[
            b in 2:number_of_blocks(inputs),
            t in commitment_indexes,
        ],
        thermal_startup[b, t] + thermal_shutdown[b, t] +
        thermal_commitment[b, t] + thermal_commitment[b-1, t]
        <=
        2
    )

    # Startup and shutdown initial conditions
    if model.stage == 1
        initial_condition_indexes =
            [t for t in commitment_indexes if has_commitment_initial_condition(inputs.collections.thermal_plant, t)]
        @constraint(
            model.jump_model,
            thermal_startup_and_shutdown_initial[
                t in initial_condition_indexes
            ],
            thermal_startup[1, t] - thermal_shutdown[1, t] ==
            thermal_commitment[1, t] - Int(thermal_plant_commitment_initial_condition(inputs, t))
        )
        @constraint(
            model.jump_model,
            thermal_commitment_is_on_initial[
                t in initial_condition_indexes
            ],
            thermal_startup[1, t] + thermal_shutdown[1, t] <=
            thermal_commitment[1, t] + Int(thermal_plant_commitment_initial_condition(inputs, t))
        )
        @constraint(
            model.jump_model,
            thermal_commitment_is_off_initial[
                t in initial_condition_indexes
            ],
            thermal_startup[1, t] + thermal_shutdown[1, t] +
            thermal_commitment[1, t] + Int(thermal_plant_commitment_initial_condition(inputs, t))
            <=
            2
        )
    end

    # Connect first block to last block
    if loop_blocks_for_thermal_constraints(inputs)
        thermal_startup_loop = get_model_object(model, :thermal_startup_loop)
        thermal_shutdown_loop = get_model_object(model, :thermal_shutdown_loop)
        @constraint(
            model.jump_model,
            thermal_startup_and_shutdown_last_block[
                t in commitment_indexes
            ],
            thermal_startup_loop[t] - thermal_shutdown_loop[t] ==
            thermal_commitment[1, t] - thermal_commitment[end, t]
        )
        @constraint(
            model.jump_model,
            thermal_commitment_is_on_last_block[
                t in commitment_indexes
            ],
            thermal_startup_loop[t] + thermal_shutdown_loop[t] <=
            thermal_commitment[1, t] + thermal_commitment[end, t]
        )
        @constraint(
            model.jump_model,
            thermal_commitment_is_off_last_block[
                t in commitment_indexes
            ],
            thermal_startup_loop[t] + thermal_shutdown_loop[t] +
            thermal_commitment[1, t] + thermal_commitment[end, t]
            <=
            2
        )
    end

    # Startup and shutdown limits
    @constraint(
        model.jump_model,
        thermal_max_startups[t in max_startup_indexes],
        sum(thermal_startup[b, t] for b in blocks(inputs))
        <=
        thermal_plant_max_startups(inputs, t)
    )
    @constraint(
        model.jump_model,
        thermal_max_shutdowns[t in max_shutdown_indexes],
        sum(thermal_shutdown[b, t] for b in blocks(inputs))
        <=
        thermal_plant_max_shutdowns(inputs, t)
    )

    return nothing
end

function thermal_startup_and_shutdown!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function thermal_startup_and_shutdown!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function thermal_startup_and_shutdown!(
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
