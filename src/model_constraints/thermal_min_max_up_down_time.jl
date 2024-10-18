#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function thermal_min_max_up_down_time! end

function thermal_min_max_up_down_time!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    # Indexes
    commitment_indexes =
        index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, has_commitment])
    minimum_up_time_indexes = [t for t in commitment_indexes if !is_null(thermal_plant_min_uptime(inputs, t))]
    minimum_down_time_indexes = [t for t in commitment_indexes if !is_null(thermal_plant_min_downtime(inputs, t))]
    maximum_up_time_indexes = [t for t in commitment_indexes if !is_null(thermal_plant_max_uptime(inputs, t))]

    # Model Variables
    thermal_commitment = get_model_object(model, :thermal_commitment)
    thermal_startup = get_model_object(model, :thermal_startup)
    thermal_shutdown = get_model_object(model, :thermal_shutdown)

    # Initial conditions
    minimum_up_time_indicator = zeros(number_of_blocks(inputs), length(minimum_up_time_indexes))
    minimum_down_time_indicator = zeros(number_of_blocks(inputs), length(minimum_down_time_indexes))
    maximum_up_time_counter = zeros(number_of_blocks(inputs), length(maximum_up_time_indexes))
    if model.stage == 1
        # Minimum uptime initial conditions
        for (i, plant_idx) in enumerate(minimum_up_time_indexes)
            uptime_initial_condition = thermal_plant_uptime_initial_condition(inputs, plant_idx)
            if is_null(uptime_initial_condition)
                continue
            end
            for b in blocks(inputs)
                # Minimum uptime indicator
                # This indicator is 1 if the plant turned on in the previous stage and has not reached the minimum uptime yet
                if uptime_initial_condition + b <= thermal_plant_min_uptime(inputs, plant_idx)
                    minimum_up_time_indicator[b, i] = 1
                else
                    minimum_up_time_indicator[b, i] = 0
                end
            end
        end

        # Minimum downtime initial conditions
        for (i, plant_idx) in enumerate(minimum_down_time_indexes)
            downtime_initial_condition = thermal_plant_downtime_initial_condition(inputs, plant_idx)
            if is_null(downtime_initial_condition)
                continue
            end
            # This indicator is 1 if the plant turned off in the previous stage and has not reached the minimum downtime yet
            for b in blocks(inputs)
                if downtime_initial_condition + b <= thermal_plant_min_downtime(inputs, plant_idx)
                    minimum_down_time_indicator[b, i] = 1
                else
                    minimum_down_time_indicator[b, i] = 0
                end
            end
        end

        # Maximum uptime initial conditions
        for (i, plant_idx) in enumerate(maximum_up_time_indexes)
            uptime_initial_condition = thermal_plant_uptime_initial_condition(inputs, plant_idx)
            if is_null(uptime_initial_condition)
                continue
            end
            # This counter indicates how many of the previous 'thermal_plant_max_uptime' subperiods the plant has been active for,
            # considering only subperiods in the previous stage
            for b in blocks(inputs)
                if b <= thermal_plant_max_uptime(inputs, plant_idx) - uptime_initial_condition + 1
                    maximum_up_time_counter[b, i] = uptime_initial_condition
                elseif b <= thermal_plant_max_uptime(inputs, plant_idx) + 1
                    maximum_up_time_counter[b, i] = thermal_plant_max_uptime(inputs, plant_idx) - b + 1
                else
                    maximum_up_time_counter[b, i] = 0
                end
            end
        end
    end

    # Constraints
    @constraint(
        model.jump_model,
        thermal_minimum_uptime[
            b in blocks(inputs),
            (i, t) in enumerate(minimum_up_time_indexes),
        ],
        sum(
            thermal_startup[j, t] for
            j in max(1, b - thermal_plant_min_uptime(inputs, t) + 1):b
        )
        +
        minimum_up_time_indicator[b, i]
        <=
        thermal_commitment[b, t]
    )

    @constraint(
        model.jump_model,
        thermal_minimum_downtime[
            b in blocks(inputs),
            (i, t) in enumerate(minimum_down_time_indexes),
        ],
        sum(
            thermal_shutdown[j, t] for
            j in max(1, b - thermal_plant_min_downtime(inputs, t) + 1):b
        )
        +
        minimum_down_time_indicator[b, i]
        <=
        1 - thermal_commitment[b, t]
    )

    @constraint(
        model.jump_model,
        thermal_maximum_uptime[
            b in blocks(inputs),
            (i, t) in enumerate(maximum_up_time_indexes),
        ],
        sum(
            thermal_commitment[b-j, t] for
            j in 0:thermal_plant_max_uptime(inputs, t) if b - j >= 1
        )
        +
        maximum_up_time_counter[b, i]
        <=
        thermal_plant_max_uptime(inputs, t)
    )

    if loop_blocks_for_thermal_constraints(inputs)
        thermal_startup_loop = get_model_object(model, :thermal_startup_loop)
        thermal_shutdown_loop = get_model_object(model, :thermal_shutdown_loop)
        # The minimum uptime and downtime constraints here are similar to the ones above, 
        # but considers one less block in the sum(), and add the 'loop' variables linking the last block to the first one
        @constraint(
            model.jump_model,
            thermal_minimum_uptime_loop[
                (i, t) in enumerate(minimum_up_time_indexes),
            ],
            sum(
                thermal_startup[j, t] for
                j in max(1, number_of_blocks(inputs) - thermal_plant_min_uptime(inputs, t) + 2):number_of_blocks(inputs)
            )
            +
            thermal_startup_loop[t]
            <=
            thermal_commitment[1, t]
        )

        @constraint(
            model.jump_model,
            thermal_minimum_downtime_loop[
                (i, t) in enumerate(minimum_down_time_indexes),
            ],
            sum(
                thermal_shutdown[j, t] for
                j in
                max(1, number_of_blocks(inputs) - thermal_plant_min_downtime(inputs, t) + 2):number_of_blocks(inputs)
            )
            +
            thermal_shutdown_loop[t]
            <=
            1 - thermal_commitment[1, t]
        )

        # The maximum uptime constraint here is similar to the one above, 
        # but considers one less block in the sum(), and adds the commitment for the first block
        @constraint(
            model.jump_model,
            thermal_maximum_uptime_loop[
                (i, t) in enumerate(maximum_up_time_indexes),
            ],
            sum(
                thermal_commitment[b, t] for
                b in (number_of_blocks(inputs)-thermal_plant_max_uptime(inputs, t)+1):number_of_blocks(inputs) if b >= 1
            )
            +
            thermal_commitment[1, t]
            <=
            thermal_plant_max_uptime(inputs, t)
        )
    end

    return nothing
end

function thermal_min_max_up_down_time!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function thermal_min_max_up_down_time!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function thermal_min_max_up_down_time!(
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
