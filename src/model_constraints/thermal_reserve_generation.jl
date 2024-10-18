#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function thermal_reserve_generation! end

function thermal_reserve_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    reserves = index_of_elements(inputs, Reserve)

    commitment_thermal_plants =
        index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, has_commitment])
    no_commit_thermal_plants =
        index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, !has_commitment])

    # Model Variables
    reserve_generation_in_thermal_plant = get_model_object(model, :reserve_generation_in_thermal_plant)
    thermal_generation = get_model_object(model, :thermal_generation)
    thermal_commitment =
        if any_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, has_commitment])
            get_model_object(model, :thermal_commitment)
        end
    # General conditions
    @constraint(
        model.jump_model,
        thermal_generation_and_reserve_upper_bound[
            b in blocks(inputs),
            t in no_commit_thermal_plants,
        ],
        thermal_generation[b, t] +
        sum(
            reserve_generation_in_thermal_plant[b, r, t]
            for r in reserves
            if t in reserve_thermal_plant_indices(inputs, r) && reserve_has_direction_up(inputs, r)
        )
        <=
        thermal_plant_max_generation(inputs, t) * block_duration_in_hours(inputs, b)
    )

    @constraint(
        model.jump_model,
        thermal_generation_and_reserve_lower_bound[
            b in blocks(inputs),
            t in no_commit_thermal_plants,
        ],
        thermal_generation[b, t] -
        sum(
            reserve_generation_in_thermal_plant[b, r, t]
            for r in reserves
            if t in reserve_thermal_plant_indices(inputs, r) && reserve_has_direction_down(inputs, r)
        )
        >=
        0.0
    )

    # Commitment plants
    if any_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, has_commitment])
        @constraint(
            model.jump_model,
            thermal_generation_and_reserve_upper_bound_in_commitment[
                b in blocks(inputs),
                t in commitment_thermal_plants,
            ],
            thermal_generation[b, t] +
            sum(
                reserve_generation_in_thermal_plant[b, r, t]
                for r in reserves
                if t in reserve_thermal_plant_indices(inputs, r) && reserve_has_direction_up(inputs, r)
            )
            <=
            thermal_plant_max_generation(inputs, t) * thermal_commitment[b, t] * block_duration_in_hours(inputs, b)
        )

        @constraint(
            model.jump_model,
            thermal_generation_and_reserve_lower_bound_in_commitment[
                b in blocks(inputs),
                t in commitment_thermal_plants,
            ],
            thermal_generation[b, t] -
            sum(
                reserve_generation_in_thermal_plant[b, r, t]
                for r in reserves
                if t in reserve_thermal_plant_indices(inputs, r) && reserve_has_direction_down(inputs, r)
            )
            >=
            thermal_plant_min_generation(inputs, t) * thermal_commitment[b, t] * block_duration_in_hours(inputs, b)
        )
    end

    # Ramp
    ramp_indexes =
        index_of_elements(inputs, ThermalPlant; run_time_options, filters = [is_existing, has_ramp_constraints])

    if any_elements(inputs, ThermalPlant; filters = [is_existing, has_ramp_constraints])
        @constraint(
            model.jump_model,
            thermal_generation_and_reserve_ramp_up[
                b in 2:number_of_blocks(inputs),
                t in ramp_indexes,
            ],
            (
                thermal_generation[b, t] +
                sum(
                    reserve_generation_in_thermal_plant[b, r, t]
                    for r in reserves
                    if t in reserve_thermal_plant_indices(inputs, r) && reserve_has_direction_up(inputs, r)
                )
            ) / block_duration_in_hours(inputs, b)
            -
            (
                thermal_generation[b-1, t] -
                sum(
                    reserve_generation_in_thermal_plant[b-1, r, t]
                    for r in reserves
                    if t in reserve_thermal_plant_indices(inputs, r) && reserve_has_direction_down(inputs, r)
                )
            ) / block_duration_in_hours(inputs, b - 1)
            <=
            thermal_plant_max_ramp_up(inputs, t) * per_minute_to_per_hour()
            * (block_duration_in_hours(inputs, b) + block_duration_in_hours(inputs, b - 1)) / 2
        )
        @constraint(
            model.jump_model,
            thermal_generation_and_reserve_ramp_down[
                b in 2:number_of_blocks(inputs),
                t in ramp_indexes,
            ],
            (
                thermal_generation[b-1, t] +
                sum(
                    reserve_generation_in_thermal_plant[b-1, r, t]
                    for r in reserves
                    if t in reserve_thermal_plant_indices(inputs, r) && reserve_has_direction_up(inputs, r)
                )
            ) / block_duration_in_hours(inputs, b - 1)
            -
            (
                thermal_generation[b, t] -
                sum(
                    reserve_generation_in_thermal_plant[b, r, t]
                    for r in reserves
                    if t in reserve_thermal_plant_indices(inputs, r) && reserve_has_direction_down(inputs, r)
                )
            ) / block_duration_in_hours(inputs, b)
            <=
            thermal_plant_max_ramp_down(inputs, t) * per_minute_to_per_hour()
            * (block_duration_in_hours(inputs, b) + block_duration_in_hours(inputs, b - 1)) / 2
        )
    end
    return nothing
end

function thermal_reserve_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function thermal_reserve_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function thermal_reserve_generation!(
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
