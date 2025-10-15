#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_generation! end

"""
    hydro_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the hydro generation variables to the model.
"""
function hydro_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    existing_hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])
    existing_hydro_units_with_min_outflow =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, has_min_outflow])
    existing_hydro_units_associated_with_some_virtual_reservoir =
        index_of_elements(
            inputs,
            HydroUnit;
            run_time_options,
            filters = [is_existing, is_associated_with_some_virtual_reservoir],
        )
    existing_hydro_units_out_of_virtual_reservoirs =
        setdiff(existing_hydro_units, existing_hydro_units_associated_with_some_virtual_reservoir)

    # Variables
    @variable(
        model.jump_model,
        hydro_turbining[b in subperiods(inputs), h in existing_hydro_units],
        lower_bound = 0.0,
        upper_bound =
            hydro_unit_max_available_turbining(inputs, h) *
            m3_per_second_to_hm3_per_hour() * subperiod_duration_in_hours(inputs, b),
    )
    @variable(
        model.jump_model,
        hydro_spillage[b in subperiods(inputs), h in existing_hydro_units],
        lower_bound = 0.0,
    )
    @variable(
        model.jump_model,
        hydro_minimum_outflow_slack[
            subperiods(inputs),
            existing_hydro_units_with_min_outflow,
        ],
        lower_bound = 0.0,
    )

    # Expressions
    @expression(
        model.jump_model,
        hydro_generation[b in subperiods(inputs), h in existing_hydro_units],
        hydro_unit_production_factor(inputs, h) * hydro_turbining[b, h] / m3_per_second_to_hm3_per_hour()
    )

    # No costs are added to the objective function in the reference curve model
    if is_reference_curve(inputs, run_time_options)
        return nothing
    end

    # Objective
    @expression(
        model.jump_model,
        hydro_minimum_outflow_violation_cost_expression[
            b in subperiods(inputs),
            h in existing_hydro_units_with_min_outflow,
        ],
        hydro_minimum_outflow_slack[b, h] * hydro_unit_minimum_outflow_violation_cost(inputs, h)
    )
    @expression(
        model.jump_model,
        hydro_spillage_penalty[b in subperiods(inputs), h in existing_hydro_units],
        hydro_spillage[b, h] * hydro_unit_spillage_cost(inputs, h)
    )

    model.obj_exp +=
        money_to_thousand_money() * sum(
            hydro_minimum_outflow_violation_cost_expression[b, h] for b in subperiods(inputs),
            h in existing_hydro_units_with_min_outflow; init = 0.0,
        )

    if !isempty(existing_hydro_units_out_of_virtual_reservoirs)
        model.obj_exp +=
            money_to_thousand_money() * sum(hydro_spillage_penalty[:, existing_hydro_units_out_of_virtual_reservoirs])
    end

    @expression(
        model.jump_model,
        hydro_om_cost_expression[b in subperiods(inputs), h in existing_hydro_units],
        hydro_generation[b, h] * hydro_unit_om_cost(inputs, h)
    )

    # Generation costs are used as a penalty in the clearing problem if the hydro unit is not associated with a virtual reservoir
    if is_market_clearing(inputs)
        if use_virtual_reservoirs(inputs)
            model.obj_exp +=
                money_to_thousand_money() *
                sum(hydro_om_cost_expression[:, existing_hydro_units_associated_with_some_virtual_reservoir])
            if !isempty(existing_hydro_units_out_of_virtual_reservoirs)
                model.obj_exp +=
                    money_to_thousand_money() *
                    sum(hydro_om_cost_expression[:, existing_hydro_units_out_of_virtual_reservoirs]) *
                    market_clearing_tiebreaker_weight(inputs)
            end
        else
            model.obj_exp +=
                money_to_thousand_money() * sum(hydro_om_cost_expression) * market_clearing_tiebreaker_weight(inputs)
        end
    else
        model.obj_exp += money_to_thousand_money() * sum(hydro_om_cost_expression)
    end

    return nothing
end

function hydro_generation!(
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

"""
    hydro_generation!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output files to store results for hydro 
- turbining
- spillage
- generation
- spillage penalty
- minimum outflow slack
- minimum outflow violation cost expression
"""
function hydro_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    hydros = index_of_elements(inputs, HydroUnit; run_time_options)

    add_symbol_to_query_from_subproblem_result!(
        outputs,
        [
            :hydro_turbining,
            :hydro_spillage,
            :hydro_generation,
            :hydro_spillage_penalty,
        ],
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_turbining",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "m3/s",
        labels = hydro_unit_label(inputs)[hydros],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_spillage",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "m3/s",
        labels = hydro_unit_label(inputs)[hydros],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_generation",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "GWh",
        labels = hydro_unit_label(inputs)[hydros],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_spillage_penalty",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "\$",
        labels = hydro_unit_label(inputs)[hydros],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_om_costs",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "\$",
        labels = hydro_unit_label(inputs)[hydros],
        run_time_options,
    )

    if any_elements(inputs, HydroUnit; run_time_options, filters = [has_min_outflow])
        add_symbol_to_query_from_subproblem_result!(
            outputs,
            [
                :hydro_minimum_outflow_slack,
                :hydro_minimum_outflow_violation_cost_expression,
            ],
        )

        hydro_units_with_minimum_outflow = index_of_elements_that_appear_at_some_point_in_study_horizon(
            inputs,
            HydroUnit;
            run_time_options,
            filters = [has_min_outflow],
        )

        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "hydro_minimum_outflow_violation_cost",
            dimensions = ["period", "scenario", "subperiod"],
            unit = "\$",
            labels = hydro_unit_label(inputs)[hydro_units_with_minimum_outflow],
            run_time_options,
        )
    end
    return nothing
end

"""
    hydro_generation!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the results for hydro
- turbining
- spillage
- generation
- spillage penalty
- minimum outflow violation cost
"""
function hydro_generation!(
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

    hydro_turbining = simulation_results.data[:hydro_turbining]
    hydro_spillage = simulation_results.data[:hydro_spillage]
    hydro_generation = simulation_results.data[:hydro_generation]
    hydro_spillage_penalty = simulation_results.data[:hydro_spillage_penalty]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_units,
        elements_to_write = existing_hydro_units,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "hydro_turbining",
        hydro_turbining.data;
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
        "hydro_spillage",
        hydro_spillage.data;
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
        "hydro_generation",
        hydro_generation.data;
        period,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "hydro_spillage_penalty",
        hydro_spillage_penalty.data;
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
        "hydro_om_costs",
        hydro_generation.data .* hydro_unit_om_cost(inputs)[existing_hydro_units]';
        period,
        scenario,
        subscenario,
        multiply_by = 1 / money_to_thousand_money(),
        indices_of_elements_in_output,
    )

    if any_elements(inputs, HydroUnit; run_time_options, filters = [has_min_outflow])
        hydro_units_with_minimum_outflow = index_of_elements(
            inputs,
            HydroUnit;
            run_time_options,
            filters = [has_min_outflow],
        )

        existing_hydro_units_with_min_outflow = index_of_elements(
            inputs,
            HydroUnit;
            run_time_options,
            filters = [is_existing, has_min_outflow],
        )

        hydro_minimum_outflow_violation_cost = simulation_results.data[:hydro_minimum_outflow_violation_cost_expression]

        indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
            elements_in_output_file = hydro_units_with_minimum_outflow,
            elements_to_write = existing_hydro_units_with_min_outflow,
        )

        write_output_per_subperiod!(
            outputs,
            inputs,
            run_time_options,
            "hydro_minimum_outflow_violation_cost",
            hydro_minimum_outflow_violation_cost.data;
            period,
            scenario,
            subscenario,
            indices_of_elements_in_output,
        )
    end
    return nothing
end
