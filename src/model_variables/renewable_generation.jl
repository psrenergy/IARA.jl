#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function renewable_generation! end

"""
    renewable_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the renewable unit generation variables to the model.
"""
function renewable_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    existing_renewables = index_of_elements(inputs, RenewableUnit; run_time_options, filters = [is_existing])

    # Time series
    subscenario = 1 # placeholder as time-series data is replaced in SubproblemUpdate functions
    renewable_generation_series = time_series_renewable_generation(inputs, run_time_options; subscenario)

    # Variables
    @variable(
        model.jump_model,
        renewable_generation[b in subperiods(inputs), r in existing_renewables],
        lower_bound = 0.0,
    )
    @variable(
        model.jump_model,
        renewable_curtailment[
            b in subperiods(inputs),
            r in existing_renewables,
        ],
        lower_bound = 0.0,
    )

    # Parameters
    @variable(
        model.jump_model,
        renewable_generation_scenario[b in subperiods(inputs), r in existing_renewables]
        in
        MOI.Parameter(renewable_generation_series[r, b])
    )

    # Objective
    model.obj_exp = @expression(
        model.jump_model,
        model.obj_exp +
        money_to_thousand_money() *
        sum(
            renewable_curtailment[b, r] * renewable_unit_curtailment_cost(inputs, r)
            for b in subperiods(inputs), r in existing_renewables
        ),
    )

    @expression(
        model.jump_model,
        renewable_total_om_cost,
        money_to_thousand_money() *
        sum(
            renewable_generation[b, r] * renewable_unit_om_cost(inputs, r)
            for b in subperiods(inputs), r in existing_renewables
        ),
    )

    # Generation costs are used as a penalty in the clearing problem
    if is_market_clearing(inputs)
        model.obj_exp += renewable_total_om_cost * market_clearing_tiebreaker_weight(inputs)
    else
        model.obj_exp += renewable_total_om_cost
    end

    return nothing
end

"""
    renewable_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemUpdate})

Updates the renewable generation variables in the model.
"""
function renewable_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    existing_renewables = index_of_elements(inputs, RenewableUnit; run_time_options, filters = [is_existing])

    # Model parameters
    renewable_generation_scenario = get_model_object(model, :renewable_generation_scenario)

    # Time Series
    renewable_generation_series = time_series_renewable_generation(inputs, run_time_options; subscenario)

    for b in subperiods(inputs), r in existing_renewables
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            renewable_generation_scenario[b, r],
            renewable_generation_series[r, b],
        )
    end

    return nothing
end

"""
    renewable_generation!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output files for
- renewable generation
- renewable curtailment
"""
function renewable_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    add_symbol_to_query_from_subproblem_result!(outputs, [:renewable_generation, :renewable_curtailment])

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "renewable_generation",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "MW",
        labels = renewable_unit_label(inputs),
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "renewable_curtailment",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "MW",
        labels = renewable_unit_label(inputs),
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "renewable_om_costs",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "\$",
        labels = renewable_unit_label(inputs),
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "renewable_curtailment_costs",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "\$",
        labels = renewable_unit_label(inputs),
        run_time_options,
    )
    return nothing
end

"""
    renewable_generation!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the renewable generation and curtailment variables' values to the output.
"""
function renewable_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    renewables = index_of_elements(inputs, RenewableUnit; run_time_options)
    existing_renewables = index_of_elements(inputs, RenewableUnit; run_time_options, filters = [is_existing])

    renewable_generation = simulation_results.data[:renewable_generation]
    renewable_curtailment = simulation_results.data[:renewable_curtailment]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = renewables,
        elements_to_write = existing_renewables,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "renewable_generation",
        renewable_generation.data;
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
        divide_by_subperiod_duration_in_hours = true,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "renewable_curtailment",
        renewable_curtailment.data;
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
        divide_by_subperiod_duration_in_hours = true,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "renewable_om_costs",
        renewable_generation.data .* renewable_unit_om_cost(inputs)[existing_renewables]';
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "renewable_curtailment_costs",
        renewable_curtailment.data .* renewable_unit_curtailment_cost(inputs)[existing_renewables]';
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )
    return nothing
end
