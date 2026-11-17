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

"""
    thermal_ramp!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the thermal unit ramp constraints to the model.
"""
function thermal_ramp!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    # Under IGNORE, consecutive subperiods are not linked, so none of these constraints are built
    if ignore_intra_period_chronology(inputs)
        return nothing
    end

    ramp_up_indexes =
        index_of_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing, has_max_ramp_up])
    ramp_down_indexes =
        index_of_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing, has_max_ramp_down])

    # Model Variables
    thermal_generation = get_model_object(model, :thermal_generation)

    # Average power [MW] in subperiod b, and time [h] between the midpoints of subperiod b and its predecessor
    average_power(b, t) = thermal_generation[b, t] / subperiod_duration_in_hours(inputs, b)
    hours_since_previous_midpoint(b) =
        (subperiod_duration_in_hours(inputs, b) + subperiod_duration_in_hours(inputs, previous_subperiod(inputs, b))) /
        2

    # Ramp constraints
    # Under CYCLIC, the last subperiod is the predecessor of the first one
    @constraint(
        model.jump_model,
        thermal_ramp_up[
            b in subperiods_with_predecessor(inputs),
            t in ramp_up_indexes,
        ],
        average_power(b, t)
        -
        average_power(previous_subperiod(inputs, b), t)
        <=
        thermal_unit_max_ramp_up(inputs, t) * per_minute_to_per_hour() * hours_since_previous_midpoint(b)
    )

    @constraint(
        model.jump_model,
        thermal_ramp_down[
            b in subperiods_with_predecessor(inputs),
            t in ramp_down_indexes,
        ],
        average_power(previous_subperiod(inputs, b), t)
        -
        average_power(b, t)
        <=
        thermal_unit_max_ramp_down(inputs, t) * per_minute_to_per_hour() * hours_since_previous_midpoint(b)
    )

    # Initial conditions
    if use_thermal_initial_conditions(inputs, model.node)
        ramp_up_initial_indexes =
            [t for t in ramp_up_indexes if !is_null(thermal_unit_generation_initial_condition(inputs, t))]
        ramp_down_initial_indexes =
            [t for t in ramp_down_indexes if !is_null(thermal_unit_generation_initial_condition(inputs, t))]

        @constraint(
            model.jump_model,
            thermal_ramp_up_initial[
                t in ramp_up_initial_indexes
            ],
            thermal_generation[1, t] / subperiod_duration_in_hours(inputs, 1)
            -
            thermal_unit_generation_initial_condition(inputs, t)
            <=
            thermal_unit_max_ramp_up(inputs, t) * per_minute_to_per_hour() * subperiod_duration_in_hours(inputs, 1)
        )

        @constraint(
            model.jump_model,
            thermal_ramp_down_initial[
                t in ramp_down_initial_indexes
            ],
            thermal_unit_generation_initial_condition(inputs, t)
            -
            thermal_generation[1, t] / subperiod_duration_in_hours(inputs, 1)
            <=
            thermal_unit_max_ramp_down(inputs, t) * per_minute_to_per_hour() * subperiod_duration_in_hours(inputs, 1)
        )
    end

    return nothing
end

function thermal_ramp!(
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
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
