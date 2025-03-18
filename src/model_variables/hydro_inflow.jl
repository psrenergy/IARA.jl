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

"""
    hydro_inflow!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the hydro inflow variables to the model.
"""
function hydro_inflow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    existing_hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])
    num_hydro_units = number_of_elements(inputs, HydroUnit; run_time_options)

    if read_inflow_from_file(inputs)
        # Time series
        subscenario = 1 # placeholder as time-series data is replaced in SubproblemUpdate functions
        inflow_series = time_series_inflow(inputs, run_time_options; subscenario)
        # Parameters
        @variable(
            model.jump_model,
            inflow[b in subperiods(inputs), h in existing_hydro_units]
            in
            MOI.Parameter(
                inflow_series[hydro_unit_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
                subperiod_duration_in_hours(inputs, b),
            ),
        )
    else
        # Time series
        inflow_noise_series = time_series_inflow_noise(inputs)

        # Parameters
        @variable(
            model.jump_model,
            inflow_noise[h in existing_hydro_units]
            in
            MOI.Parameter(
                inflow_noise_series[hydro_unit_gauging_station_index(inputs, h)],
            ),
        )

        if parp_max_lags(inputs) > 0
            # Initial state
            normalized_initial_state = zeros(num_hydro_units, parp_max_lags(inputs))
            for h in existing_hydro_units, tau in 1:parp_max_lags(inputs)
                period_idx = mod1(period_index_in_year(inputs, tau) - parp_max_lags(inputs), periods_per_year(inputs))
                normalized_initial_state[h, tau] = normalized_initial_inflow(inputs, period_idx, h, tau)
            end
            # Time series
            inflow_noise_series = time_series_inflow_noise(inputs)
            # State variables
            @variable(
                model.jump_model,
                normalized_inflow[
                    h in existing_hydro_units,
                    tau in 1:parp_max_lags(inputs),
                ],
                SDDP.State,
                initial_value = normalized_initial_state[h, tau],
            )
        end

        # Denormalize inflow and convert to hm³
        # Repeat the same value for all subperiods
        inflow_multiplier = [AffExpr(0) for h in index_of_elements(inputs, HydroUnit; run_time_options)]
        if parp_max_lags(inputs) > 0
            for h in existing_hydro_units
                inflow_multiplier[h] = normalized_inflow[h, end].out
            end
        else
            for h in existing_hydro_units
                inflow_multiplier[h] = inflow_noise[hydro_unit_gauging_station_index(inputs, h)]
            end
        end
        @expression(
            model.jump_model,
            inflow[b in subperiods(inputs), h in existing_hydro_units],
            m3_per_second_to_hm3_per_hour() * subperiod_duration_in_hours(inputs, b) *
            (
                inflow_multiplier[h] *
                time_series_inflow_period_std_dev(inputs)[
                    hydro_unit_gauging_station_index(inputs, h),
                    period_index_in_year(inputs, model.node),
                ] +
                time_series_inflow_period_average(inputs)[
                    hydro_unit_gauging_station_index(inputs, h),
                    period_index_in_year(inputs, model.node),
                ]
            )
        )
    end

    # Slack variables
    @variable(
        model.jump_model,
        inflow_slack[b in subperiods(inputs), h in existing_hydro_units],
        lower_bound = 0.0,
    )

    # Objective
    inflow_slack_weight = [
        1.1 .* hydro_unit_downstream_cumulative_production_factor(inputs, h) .* demand_deficit_cost(inputs) /
        m3_per_second_to_hm3_per_hour() for h in existing_hydro_units
    ]
    @expression(
        model.jump_model,
        inflow_slack_penalty[b in subperiods(inputs), (idx, h) in enumerate(existing_hydro_units)],
        inflow_slack[b, h] * inflow_slack_weight[idx]
    )
    model.obj_exp += sum(inflow_slack_penalty) * money_to_thousand_money()

    return nothing
end

"""
    hydro_inflow!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, scenario, subscenario, ::Type{SubproblemUpdate})

Updates the hydro inflow variables in the model.
"""
function hydro_inflow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])

    if read_inflow_from_file(inputs)
        # Model parameters
        inflow = get_model_object(model, :inflow)

        # Time series
        inflow_series = time_series_inflow(inputs, run_time_options; subscenario)

        for b in subperiods(inputs), h in hydro_units
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                inflow[b, h],
                inflow_series[hydro_unit_gauging_station_index(inputs, h), b] * m3_per_second_to_hm3_per_hour() *
                subperiod_duration_in_hours(inputs, b),
            )
        end
    else
        # Model parameters
        inflow_noise = get_model_object(model, :inflow_noise)

        # Time series
        inflow_noise_series = time_series_inflow_noise(inputs)

        for h in hydro_units
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                inflow_noise[h],
                inflow_noise_series[hydro_unit_gauging_station_index(inputs, h)],
            )
        end
    end

    return nothing
end

"""
    hydro_inflow!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output files for
- inflow    
- inflow_slack
"""
function hydro_inflow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydros = index_of_elements(inputs, HydroUnit; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, [:inflow_slack, :inflow])

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "inflow_slack",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "m3/s",
        labels = hydro_unit_label(inputs)[hydros],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "inflow",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "m3/s",
        labels = hydro_unit_label(inputs)[hydros],
        run_time_options,
    )

    return nothing
end

"""
    hydro_inflow!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})    

Write the inflow and inflow_slack values to the output file.
"""
function hydro_inflow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    hydro_units = index_of_elements(inputs, HydroUnit; run_time_options)
    existing_hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])

    inflow_slack = simulation_results.data[:inflow_slack]
    inflow = simulation_results.data[:inflow]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_units,
        elements_to_write = existing_hydro_units,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "inflow_slack",
        inflow_slack.data;
        period,
        scenario,
        subscenario,
        multiply_by = 1 / m3_per_second_to_hm3_per_hour(),
        divide_by_subperiod_duration_in_hours = true,
        indices_of_elements_in_output,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "inflow",
        inflow.data;
        period,
        scenario,
        subscenario,
        multiply_by = 1 / m3_per_second_to_hm3_per_hour(),
        divide_by_subperiod_duration_in_hours = true,
        indices_of_elements_in_output,
    )

    return nothing
end
