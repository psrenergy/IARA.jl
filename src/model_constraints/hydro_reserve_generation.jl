#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_reserve_generation! end

function hydro_reserve_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    hydro_plants = index_of_elements(inputs, HydroPlant; filters = [is_existing])
    no_commit_hydro_plants = index_of_elements(inputs, HydroPlant; filters = [is_existing, !has_commitment])
    commitment_hydro_plants = index_of_elements(inputs, HydroPlant; filters = [is_existing, has_commitment])
    reserves = index_of_elements(inputs, Reserve)

    # Model Variables
    reserve_generation_in_hydro_plant = get_model_object(model, :reserve_generation_in_hydro_plant)
    hydro_generation = get_model_object(model, :hydro_generation)
    hydro_spillage = get_model_object(model, :hydro_spillage)
    hydro_volume = get_model_object(model, :hydro_volume)
    hydro_commitment = if any_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, has_commitment])
        get_model_object(model, :hydro_commitment)
    end
    # General conditions
    @constraint(
        model.jump_model,
        hydro_generation_and_reserve_upper_bound[
            b in blocks(inputs),
            h in no_commit_hydro_plants,
        ],
        hydro_generation[b, h] +
        sum(
            reserve_generation_in_hydro_plant[b, r, h]
            for r in reserves
            if h in reserve_hydro_plant_indices(inputs, r) && reserve_has_direction_up(inputs, r)
        )
        <=
        hydro_plant_max_generation(inputs, h) * block_duration_in_hours(inputs, b)
    )

    @constraint(
        model.jump_model,
        hydro_generation_and_reserve_lower_bound[
            b in blocks(inputs),
            h in no_commit_hydro_plants,
        ],
        hydro_generation[b, h] -
        sum(
            reserve_generation_in_hydro_plant[b, r, h]
            for r in reserves
            if h in reserve_hydro_plant_indices(inputs, r) && reserve_has_direction_down(inputs, r)
        )
        >=
        0.0
    )

    @constraint(
        model.jump_model,
        water_availability_for_hydro_reserve[
            b in blocks(inputs),
            h in hydro_plants,
        ],
        hydro_plant_production_factor(inputs, h) * (hydro_spillage[b, h] + hydro_volume[b, h]) /
        m3_per_second_to_hm3_per_hour()
        >=
        sum(
            reserve_generation_in_hydro_plant[b, r, h]
            for r in reserves
            if h in reserve_hydro_plant_indices(inputs, r)
        )
    )

    # Commitment plants
    if any_elements(inputs, HydroPlant; run_time_options, filters = [is_existing, has_commitment])
        @constraint(
            model.jump_model,
            hydro_generation_and_reserve_upper_bound_in_commitment[
                b in blocks(inputs),
                h in commitment_hydro_plants,
            ],
            hydro_generation[b, h] +
            sum(
                reserve_generation_in_hydro_plant[b, r, h]
                for r in reserves
                if h in reserve_hydro_plant_indices(inputs, r) && reserve_has_direction_up(inputs, r)
            )
            <=
            hydro_plant_max_generation(inputs, h) * hydro_commitment[b, h] * block_duration_in_hours(inputs, b)
        )

        @constraint(
            model.jump_model,
            hydro_generation_and_reserve_lower_bound_in_commitment[
                b in blocks(inputs),
                h in commitment_hydro_plants,
            ],
            hydro_generation[b, h] -
            sum(
                reserve_generation_in_hydro_plant[b, r, h]
                for r in reserves
                if h in reserve_hydro_plant_indices(inputs, r) && reserve_has_direction_down(inputs, r)
            )
            >=
            hydro_plant_min_generation(inputs, h) * hydro_commitment[b, h] * block_duration_in_hours(inputs, b)
        )
    end

    return nothing
end

function hydro_reserve_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function hydro_reserve_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function hydro_reserve_generation!(
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
