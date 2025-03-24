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

"""
    thermal_min_max_up_down_time!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the thermal unit minimum and maximum up and down time constraints to the model.
"""
function thermal_min_max_up_down_time!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    # Indexes
    commitment_indexes =
        index_of_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing, has_commitment])
    minimum_up_time_indexes = [t for t in commitment_indexes if !is_null(thermal_unit_min_uptime(inputs, t))]
    minimum_down_time_indexes = [t for t in commitment_indexes if !is_null(thermal_unit_min_downtime(inputs, t))]
    maximum_up_time_indexes = [t for t in commitment_indexes if !is_null(thermal_unit_max_uptime(inputs, t))]

    # Model Variables
    thermal_commitment = get_model_object(model, :thermal_commitment)
    thermal_startup = get_model_object(model, :thermal_startup)
    thermal_shutdown = get_model_object(model, :thermal_shutdown)

    # Initial conditions
    minimum_up_time_indicator = zeros(number_of_subperiods(inputs), length(minimum_up_time_indexes))
    minimum_down_time_indicator = zeros(number_of_subperiods(inputs), length(minimum_down_time_indexes))
    maximum_up_time_counter = zeros(number_of_subperiods(inputs), length(maximum_up_time_indexes))
    if model.node == 1
        # Minimum uptime initial conditions
        for (i, plant_idx) in enumerate(minimum_up_time_indexes)
            uptime_initial_condition = thermal_unit_uptime_initial_condition(inputs, plant_idx)
            if is_null(uptime_initial_condition)
                continue
            end
            sum_of_previous_subperiods_duration = 0.0
            for b in subperiods(inputs)
                # Minimum uptime indicator
                # This indicator is 1 if the plant turned on in the previous period and has not reached the minimum uptime yet
                if uptime_initial_condition + sum_of_previous_subperiods_duration <
                   thermal_unit_min_uptime(inputs, plant_idx)
                    minimum_up_time_indicator[b, i] = 1
                else
                    minimum_up_time_indicator[b, i] = 0
                end
                sum_of_previous_subperiods_duration += subperiod_duration_in_hours(inputs, b)
            end
        end

        # Minimum downtime initial conditions
        for (i, plant_idx) in enumerate(minimum_down_time_indexes)
            downtime_initial_condition = thermal_unit_downtime_initial_condition(inputs, plant_idx)
            if is_null(downtime_initial_condition)
                continue
            end
            sum_of_previous_subperiods_duration = 0
            # This indicator is 1 if the plant turned off in the previous period and has not reached the minimum downtime yet
            for b in subperiods(inputs)
                if downtime_initial_condition + sum_of_previous_subperiods_duration <
                   thermal_unit_min_downtime(inputs, plant_idx)
                    minimum_down_time_indicator[b, i] = 1
                else
                    minimum_down_time_indicator[b, i] = 0
                end
                sum_of_previous_subperiods_duration += subperiod_duration_in_hours(inputs, b)
            end
        end

        # Maximum uptime initial conditions
        for (i, plant_idx) in enumerate(maximum_up_time_indexes)
            uptime_initial_condition = thermal_unit_uptime_initial_condition(inputs, plant_idx)
            if is_null(uptime_initial_condition)
                continue
            end
            # This counter indicates how many of the previous 'thermal_unit_max_uptime' hours the plant has been active for,
            # considering only subperiods in the previous period
            sum_of_previous_subperiods_duration = 0.0
            for b in subperiods(inputs)
                if uptime_initial_condition + sum_of_previous_subperiods_duration <=
                   thermal_unit_max_uptime(inputs, plant_idx)
                    maximum_up_time_counter[b, i] = uptime_initial_condition
                elseif sum_of_previous_subperiods_duration <= thermal_unit_max_uptime(inputs, plant_idx)
                    maximum_up_time_counter[b, i] =
                        thermal_unit_max_uptime(inputs, plant_idx) - sum_of_previous_subperiods_duration
                else
                    maximum_up_time_counter[b, i] = 0
                end
                sum_of_previous_subperiods_duration += subperiod_duration_in_hours(inputs, b)
            end
        end
    end

    first_subperiod_that_matters_for_min_uptime_map =
        zeros(Int, number_of_subperiods(inputs), length(minimum_up_time_indexes))
    for b in subperiods(inputs)
        first_subperiod_that_matters_for_min_uptime_map[b, :] .= b
        subperiod_duration_sum = 0
        for some_previous_subperiod in b-1:-1:1
            subperiod_duration_sum += subperiod_duration_in_hours(inputs, some_previous_subperiod)
            for (i, plant_idx) in enumerate(minimum_up_time_indexes)
                if subperiod_duration_sum < thermal_unit_min_uptime(inputs, plant_idx)
                    first_subperiod_that_matters_for_min_uptime_map[b, i] = some_previous_subperiod
                end
            end
        end
    end

    # Constraints
    @constraint(
        model.jump_model,
        thermal_minimum_uptime[
            b in subperiods(inputs),
            (i, t) in enumerate(minimum_up_time_indexes),
        ],
        sum(
            thermal_startup[j, t] for
            j in first_subperiod_that_matters_for_min_uptime_map[b, i]:b
        )
        +
        minimum_up_time_indicator[b, i]
        <=
        thermal_commitment[b, t]
    )

    first_subperiod_that_matters_for_min_downtime_map =
        zeros(Int, number_of_subperiods(inputs), length(minimum_down_time_indexes))

    for b in subperiods(inputs)
        first_subperiod_that_matters_for_min_downtime_map[b, :] .= b
        subperiod_duration_sum = 0
        for some_previous_subperiod in b-1:-1:1
            subperiod_duration_sum += subperiod_duration_in_hours(inputs, some_previous_subperiod)
            for (i, plant_idx) in enumerate(minimum_down_time_indexes)
                if subperiod_duration_sum < thermal_unit_min_downtime(inputs, plant_idx)
                    first_subperiod_that_matters_for_min_downtime_map[b, i] = some_previous_subperiod
                end
            end
        end
    end

    @constraint(
        model.jump_model,
        thermal_minimum_downtime[
            b in subperiods(inputs),
            (i, t) in enumerate(minimum_down_time_indexes),
        ],
        sum(
            thermal_shutdown[j, t] for
            j in first_subperiod_that_matters_for_min_downtime_map[b, i]:b
        )
        +
        minimum_down_time_indicator[b, i]
        <=
        1 - thermal_commitment[b, t]
    )

    first_subperiod_that_matters_for_max_uptime_map =
        zeros(Int, number_of_subperiods(inputs), length(maximum_up_time_indexes))

    for b in subperiods(inputs)
        first_subperiod_that_matters_for_max_uptime_map[b, :] .= b
        subperiod_duration_sum = 0
        for some_previous_subperiod in b-1:-1:1
            subperiod_duration_sum += subperiod_duration_in_hours(inputs, some_previous_subperiod)
            for (i, plant_idx) in enumerate(maximum_up_time_indexes)
                if subperiod_duration_sum <= thermal_unit_max_uptime(inputs, plant_idx)
                    first_subperiod_that_matters_for_max_uptime_map[b, i] = some_previous_subperiod
                end
            end
        end
    end

    @constraint(
        model.jump_model,
        thermal_maximum_uptime[
            b in subperiods(inputs),
            (i, t) in enumerate(maximum_up_time_indexes),
        ],
        sum(
            thermal_commitment[j, t] * subperiod_duration_in_hours(inputs, j) for
            j in first_subperiod_that_matters_for_max_uptime_map[b, i]:b
        )
        +
        maximum_up_time_counter[b, i]
        <=
        thermal_unit_max_uptime(inputs, t)
    )

    if loop_subperiods_for_thermal_constraints(inputs)
        thermal_startup_loop = get_model_object(model, :thermal_startup_loop)
        thermal_shutdown_loop = get_model_object(model, :thermal_shutdown_loop)
        # The minimum uptime and downtime constraints here are similar to the ones above, 
        # but considers one less subperiod in the sum(), and add the 'loop' variables linking the last subperiod to the first one

        first_subperiod_that_matters_for_loop_min_uptime_map = zeros(Int, length(minimum_up_time_indexes))
        for (i, plant_idx) in enumerate(minimum_up_time_indexes)
            first_subperiod_that_matters_for_loop_min_uptime_map[i] = 0
            subperiod_duration_sum = 0
            for some_previous_subperiod in
                number_of_subperiods(inputs):-1:first_subperiod_that_matters_for_max_uptime_map[end, i]
                subperiod_duration_sum += subperiod_duration_in_hours(inputs, some_previous_subperiod)
                if subperiod_duration_sum < thermal_unit_min_uptime(inputs, plant_idx)
                    first_subperiod_that_matters_for_loop_min_uptime_map[i] = some_previous_subperiod
                end
            end
        end

        @constraint(
            model.jump_model,
            thermal_minimum_uptime_loop[
                (i, t) in enumerate(minimum_up_time_indexes);
                first_subperiod_that_matters_for_loop_min_uptime_map[i] > 0
            ],
            sum(
                thermal_startup[j, t] for
                j in first_subperiod_that_matters_for_loop_min_uptime_map[i]:number_of_subperiods(inputs)
            )
            +
            thermal_startup_loop[t]
            <=
            thermal_commitment[1, t]
        )

        first_subperiod_that_matters_for_loop_min_downtime_map = zeros(Int, length(minimum_down_time_indexes))
        for (i, plant_idx) in enumerate(minimum_down_time_indexes)
            first_subperiod_that_matters_for_loop_min_downtime_map[i] = 0
            subperiod_duration_sum = 0
            for some_previous_subperiod in
                number_of_subperiods(inputs):-1:first_subperiod_that_matters_for_max_uptime_map[end, i]
                subperiod_duration_sum += subperiod_duration_in_hours(inputs, some_previous_subperiod)
                if subperiod_duration_sum < thermal_unit_min_downtime(inputs, plant_idx)
                    first_subperiod_that_matters_for_loop_min_downtime_map[i] = some_previous_subperiod
                end
            end
        end

        @constraint(
            model.jump_model,
            thermal_minimum_downtime_loop[
                (i, t) in enumerate(minimum_down_time_indexes);
                first_subperiod_that_matters_for_loop_min_downtime_map[i] > 0
            ],
            sum(
                thermal_shutdown[j, t] for
                j in first_subperiod_that_matters_for_loop_min_downtime_map[i]:number_of_subperiods(inputs)
            )
            +
            thermal_shutdown_loop[t]
            <=
            1 - thermal_commitment[1, t]
        )

        # The maximum uptime constraint here is similar to the one above, 
        # but considers one less subperiod in the sum(), and adds the commitment for the first subperiod

        first_subperiod_that_matters_for_loop_max_uptime_map = zeros(Int, length(maximum_up_time_indexes))
        for (i, plant_idx) in enumerate(maximum_up_time_indexes)
            first_subperiod_that_matters_for_loop_max_uptime_map[i] = 0
            subperiod_duration_sum = 0
            for some_previous_subperiod in
                number_of_subperiods(inputs):-1:first_subperiod_that_matters_for_max_uptime_map[end, i]
                subperiod_duration_sum += subperiod_duration_in_hours(inputs, some_previous_subperiod)
                if subperiod_duration_sum <= thermal_unit_max_uptime(inputs, plant_idx)
                    first_subperiod_that_matters_for_loop_max_uptime_map[i] = some_previous_subperiod
                end
            end
        end

        @constraint(
            model.jump_model,
            thermal_maximum_uptime_loop[
                (i, t) in enumerate(maximum_up_time_indexes);
                first_subperiod_that_matters_for_loop_max_uptime_map[i] > 0
            ],
            sum(
                thermal_commitment[b, t] * subperiod_duration_in_hours(inputs, b) for
                b in first_subperiod_that_matters_for_loop_max_uptime_map[i]:number_of_subperiods(inputs)
            )
            +
            thermal_commitment[1, t] * subperiod_duration_in_hours(inputs, 1)
            <=
            thermal_unit_max_uptime(inputs, t)
        )
    end

    return nothing
end

function thermal_min_max_up_down_time!(
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
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
