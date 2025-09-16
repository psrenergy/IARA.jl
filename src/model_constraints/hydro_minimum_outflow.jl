#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_minimum_outflow! end

"""
    hydro_minimum_outflow!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the hydro minimum outflow constraints to the model.
"""
function hydro_minimum_outflow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    minimum_outflow_indexes =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, has_min_outflow])

    # Model Variables
    hydro_turbining = get_model_object(model, :hydro_turbining)
    hydro_spillage = get_model_object(model, :hydro_spillage)
    hydro_minimum_outflow_slack = get_model_object(model, :hydro_minimum_outflow_slack)

    # Constraints
    @constraint(
        model.jump_model,
        hydro_minimum_outflow[
            b in subperiods(inputs),
            h in minimum_outflow_indexes,
        ],
        hydro_spillage[b, h] + hydro_turbining[b, h] + hydro_minimum_outflow_slack[b, h] >=
        hydro_unit_min_outflow(inputs, h) * m3_per_second_to_hm3_per_hour() * subperiod_duration_in_hours(inputs, b)
    )

    return nothing
end

function hydro_minimum_outflow!(
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

function hydro_minimum_outflow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    add_custom_recorder_to_query_from_subproblem_result!(
        outputs,
        :hydro_minimum_outflow_marginal_cost,
        constraint_dual_recorder(inputs, :hydro_minimum_outflow),
    )

    hydro_units_with_minimum_outflow =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [has_min_outflow])

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_minimum_outflow_marginal_cost",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "\$/hm3",
        labels = hydro_unit_label(inputs)[hydro_units_with_minimum_outflow],
        run_time_options,
    )
    return nothing
end

function hydro_minimum_outflow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    hydro_minimum_outflow_marginal_cost = simulation_results.data[:hydro_minimum_outflow_marginal_cost]

    hydro_units_with_minimum_outflow =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [has_min_outflow])
    existing_hydro_units_with_min_outflow =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, has_min_outflow])

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = hydro_units_with_minimum_outflow,
        elements_to_write = existing_hydro_units_with_min_outflow,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "hydro_minimum_outflow_marginal_cost",
        hydro_minimum_outflow_marginal_cost.data;
        period,
        scenario,
        subscenario,
        multiply_by = 1 / money_to_thousand_money(),
        indices_of_elements_in_output,
    )

    return nothing
end
