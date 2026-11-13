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
    # Under IGNORE, consecutive subperiods are not linked, so none of these constraints are built
    if ignore_intra_period_chronology(inputs)
        return nothing
    end

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
    if use_thermal_initial_conditions(inputs, model.node)
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

    # Lookback windows: subperiod b followed by the predecessors that still bind it.
    # Under CYCLIC, the windows wrap around from the first subperiod to the last one.
    minimum_up_time_window = [
        lookback_subperiods(inputs, b, thermal_unit_min_uptime(inputs, t)) for
        b in subperiods(inputs), t in minimum_up_time_indexes
    ]
    minimum_down_time_window = [
        lookback_subperiods(inputs, b, thermal_unit_min_downtime(inputs, t)) for
        b in subperiods(inputs), t in minimum_down_time_indexes
    ]
    maximum_up_time_window = [
        lookback_subperiods(inputs, b, thermal_unit_max_uptime(inputs, t); include_boundary = true) for
        b in subperiods(inputs), t in maximum_up_time_indexes
    ]

    # Constraints
    @constraint(
        model.jump_model,
        thermal_minimum_uptime[
            b in subperiods(inputs),
            (i, t) in enumerate(minimum_up_time_indexes),
        ],
        sum(thermal_startup[j, t] for j in minimum_up_time_window[b, i])
        +
        minimum_up_time_indicator[b, i]
        <=
        thermal_commitment[b, t]
    )

    @constraint(
        model.jump_model,
        thermal_minimum_downtime[
            b in subperiods(inputs),
            (i, t) in enumerate(minimum_down_time_indexes),
        ],
        sum(thermal_shutdown[j, t] for j in minimum_down_time_window[b, i])
        +
        minimum_down_time_indicator[b, i]
        <=
        1 - thermal_commitment[b, t]
    )

    @constraint(
        model.jump_model,
        thermal_maximum_uptime[
            b in subperiods(inputs),
            (i, t) in enumerate(maximum_up_time_indexes),
        ],
        sum(
            thermal_commitment[j, t] * subperiod_duration_in_hours(inputs, j) for
            j in maximum_up_time_window[b, i]
        )
        +
        maximum_up_time_counter[b, i]
        <=
        thermal_unit_max_uptime(inputs, t)
    )

    return nothing
end

"""
    lookback_subperiods(inputs::AbstractInputs, subperiod::Int, hours::Real; include_boundary::Bool = false)

Return `subperiod` followed by its predecessors, walking back while the accumulated duration of the predecessors
is strictly below `hours` (or at most `hours`, when `include_boundary` is true).
Under `CYCLIC`, the walk wraps around from the first subperiod to the last one, and stops before any subperiod
would be visited twice.
"""
function lookback_subperiods(inputs::AbstractInputs, subperiod::Int, hours::Real; include_boundary::Bool = false)
    window = [subperiod]
    accumulated_duration = 0.0
    current = subperiod
    for _ in 1:number_of_subperiods(inputs)-1
        current = previous_subperiod(inputs, current)
        if isnothing(current)
            break
        end
        accumulated_duration += subperiod_duration_in_hours(inputs, current)
        is_within_window = include_boundary ? accumulated_duration <= hours : accumulated_duration < hours
        if !is_within_window
            break
        end
        push!(window, current)
    end
    return window
end

function thermal_min_max_up_down_time!(
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
