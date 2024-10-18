#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_inflow! end

function hydro_inflow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    num_existing_hydros = number_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])
    existing_hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])

    if read_inflow_from_file(inputs)
        # Time series
        inflow_series = time_series_inflow(inputs)
        # Parameters
        @variable(
            model.jump_model,
            inflow[b in blocks(inputs), h in existing_hydro_plants]
            in
            MOI.Parameter(
                inflow_series[hydro_plant_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
                block_duration_in_hours(inputs, b),
            ),
        )
    else
        # Time series
        inflow_noise_series = time_series_inflow_noise(inputs)

        # Parameters
        @variable(
            model.jump_model,
            inflow_noise[h in existing_hydro_plants]
            in
            MOI.Parameter(
                inflow_noise_series[hydro_plant_gauging_station_index(inputs, h)],
            ),
        )

        if parp_max_lags(inputs) > 0
            # Initial state
            normalized_initial_state = zeros(num_existing_hydros, parp_max_lags(inputs))
            for h in existing_hydro_plants, tau in 1:parp_max_lags(inputs)
                stage_idx = mod1(stage_index_in_year(inputs, tau) - parp_max_lags(inputs), stages_per_year(inputs))
                normalized_initial_state[h, tau] = normalized_initial_inflow(inputs, stage_idx, h, tau)
            end
            # Time series
            inflow_noise_series = time_series_inflow_noise(inputs)
            # State variables
            @variable(
                model.jump_model,
                normalized_inflow[
                    h in existing_hydro_plants,
                    tau in 1:parp_max_lags(inputs),
                ],
                SDDP.State,
                initial_value = normalized_initial_state[h, tau],
            )
        end

        # Denormalize inflow and convert to hm³
        # Repeat the same value for all blocks
        inflow_multiplier = [AffExpr(0) for h in index_of_elements(inputs, HydroPlant; run_time_options)]
        if parp_max_lags(inputs) > 0
            for h in existing_hydro_plants
                inflow_multiplier[h] = normalized_inflow[h, end].out
            end
        else
            for h in existing_hydro_plants
                inflow_multiplier[h] = inflow_noise[hydro_plant_gauging_station_index(inputs, h)]
            end
        end
        @expression(
            model.jump_model,
            inflow[b in blocks(inputs), h in existing_hydro_plants],
            m3_per_second_to_hm3_per_hour() * block_duration_in_hours(inputs, b) *
            (
                inflow_multiplier[h] *
                time_series_inflow_stage_std_dev(inputs)[
                    hydro_plant_gauging_station_index(inputs, h),
                    stage_index_in_year(inputs, model.stage),
                ] +
                time_series_inflow_stage_average(inputs)[
                    hydro_plant_gauging_station_index(inputs, h),
                    stage_index_in_year(inputs, model.stage),
                ]
            )
        )
    end

    # Slack variables
    @variable(
        model.jump_model,
        inflow_slack[b in blocks(inputs), h in existing_hydro_plants],
        lower_bound = 0.0,
    )

    # Objective
    inflow_slack_weight = [
        1.1 .* hydro_plant_downstream_cumulative_production_factor(inputs, h) .* demand_deficit_cost(inputs) /
        m3_per_second_to_hm3_per_hour() for h in existing_hydro_plants
    ]
    @expression(
        model.jump_model,
        inflow_slack_penalty[b in blocks(inputs), (idx, h) in enumerate(existing_hydro_plants)],
        inflow_slack[b, h] * inflow_slack_weight[idx]
    )
    model.obj_exp += sum(inflow_slack_penalty) * money_to_thousand_money()

    return nothing
end

function hydro_inflow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])

    if read_inflow_from_file(inputs)
        # Model parameters
        inflow = get_model_object(model, :inflow)

        # Time series
        inflow_series = time_series_inflow(inputs, run_time_options, subscenario)

        for b in blocks(inputs), h in hydro_plants
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                inflow[b, h],
                inflow_series[hydro_plant_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
                block_duration_in_hours(inputs, b),
            )
        end
    else
        # Model parameters
        inflow_noise = get_model_object(model, :inflow_noise)

        # Time series
        inflow_noise_series = time_series_inflow_noise(inputs)

        for h in hydro_plants
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                inflow_noise[h],
                inflow_noise_series[hydro_plant_gauging_station_index(inputs, h)],
            )
        end
    end

    return nothing
end

function hydro_inflow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydros = index_of_elements(inputs, HydroPlant; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, [:inflow_slack, :inflow])

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "inflow_slack",
        dimensions = ["stage", "scenario", "block"],
        unit = "m3/s",
        labels = hydro_plant_label(inputs)[hydros],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "inflow",
        dimensions = ["stage", "scenario", "block"],
        unit = "m3/s",
        labels = hydro_plant_label(inputs)[hydros],
        run_time_options,
    )

    return nothing
end

function hydro_inflow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options)
    existing_hydro_plants = index_of_elements(inputs, HydroPlant; run_time_options, filters = [is_existing])

    inflow_slack = simulation_results.data[:inflow_slack]
    inflow = simulation_results.data[:inflow]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_plants,
        elements_to_write = existing_hydro_plants,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "inflow_slack",
        inflow_slack.data;
        stage,
        scenario,
        subscenario,
        multiply_by = 1 / m3_per_second_to_hm3_per_hour(),
        divide_by_block_duration_in_hours = true,
        indices_of_elements_in_output,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "inflow",
        inflow.data;
        stage,
        scenario,
        subscenario,
        multiply_by = 1 / m3_per_second_to_hm3_per_hour(),
        divide_by_block_duration_in_hours = true,
        indices_of_elements_in_output,
    )

    return nothing
end
