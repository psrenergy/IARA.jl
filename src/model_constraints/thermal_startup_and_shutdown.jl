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

"""
    thermal_startup_and_shutdown!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the thermal unit startup and shutdown constraints to the model.
"""
function thermal_startup_and_shutdown!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    # Under IGNORE, consecutive subperiods are not linked, so none of these constraints are built
    if ignore_intra_period_chronology(inputs)
        return nothing
    end

    commitment_indexes =
        index_of_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing, has_commitment])
    max_startup_indexes = [t for t in commitment_indexes if !is_null(thermal_unit_max_startups(inputs, t))]
    max_shutdown_indexes = [t for t in commitment_indexes if !is_null(thermal_unit_max_shutdowns(inputs, t))]

    # Model Variables
    thermal_commitment = get_model_object(model, :thermal_commitment)
    thermal_startup = get_model_object(model, :thermal_startup)
    thermal_shutdown = get_model_object(model, :thermal_shutdown)

    # Startup and shutdown definition
    # Under CYCLIC, the last subperiod is the predecessor of the first one
    @constraint(
        model.jump_model,
        thermal_startup_and_shutdown[
            b in subperiods_with_predecessor(inputs),
            t in commitment_indexes,
        ],
        thermal_startup[b, t] - thermal_shutdown[b, t] ==
        thermal_commitment[b, t] - thermal_commitment[previous_subperiod(inputs, b), t]
    )
    @constraint(
        model.jump_model,
        thermal_commitment_is_on[
            b in subperiods_with_predecessor(inputs),
            t in commitment_indexes,
        ],
        thermal_startup[b, t] + thermal_shutdown[b, t] <=
        thermal_commitment[b, t] + thermal_commitment[previous_subperiod(inputs, b), t]
    )
    @constraint(
        model.jump_model,
        thermal_commitment_is_off[
            b in subperiods_with_predecessor(inputs),
            t in commitment_indexes,
        ],
        thermal_startup[b, t] + thermal_shutdown[b, t] +
        thermal_commitment[b, t] + thermal_commitment[previous_subperiod(inputs, b), t]
        <=
        2
    )

    # Startup and shutdown initial conditions
    if use_thermal_initial_conditions(inputs, model.node)
        initial_condition_indexes =
            [t for t in commitment_indexes if has_commitment_initial_condition(inputs.collections.thermal_unit, t)]
        @constraint(
            model.jump_model,
            thermal_startup_and_shutdown_initial[
                t in initial_condition_indexes
            ],
            thermal_startup[1, t] - thermal_shutdown[1, t] ==
            thermal_commitment[1, t] - Int(thermal_unit_commitment_initial_condition(inputs, t))
        )
        @constraint(
            model.jump_model,
            thermal_commitment_is_on_initial[
                t in initial_condition_indexes
            ],
            thermal_startup[1, t] + thermal_shutdown[1, t] <=
            thermal_commitment[1, t] + Int(thermal_unit_commitment_initial_condition(inputs, t))
        )
        @constraint(
            model.jump_model,
            thermal_commitment_is_off_initial[
                t in initial_condition_indexes
            ],
            thermal_startup[1, t] + thermal_shutdown[1, t] +
            thermal_commitment[1, t] + Int(thermal_unit_commitment_initial_condition(inputs, t))
            <=
            2
        )
    end

    # Startup and shutdown limits
    @constraint(
        model.jump_model,
        thermal_max_startups[t in max_startup_indexes],
        sum(thermal_startup[b, t] for b in subperiods(inputs))
        <=
        thermal_unit_max_startups(inputs, t)
    )
    @constraint(
        model.jump_model,
        thermal_max_shutdowns[t in max_shutdown_indexes],
        sum(thermal_shutdown[b, t] for b in subperiods(inputs))
        <=
        thermal_unit_max_shutdowns(inputs, t)
    )

    return nothing
end

function thermal_startup_and_shutdown!(
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
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
