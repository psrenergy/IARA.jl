#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function thermal_commitment! end

"""
    thermal_commitment!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the thermal unit commitment variables to the model.
"""
function thermal_commitment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    commitment_indexes =
        index_of_elements(inputs, ThermalUnit; run_time_options, filters = [is_existing, has_commitment])

    @variable(
        model.jump_model,
        thermal_commitment[
            b in subperiods(inputs),
            t in commitment_indexes,
        ],
        binary = true,
    )

    if use_binary_variables(inputs, run_time_options)
        add_symbol_to_integer_variables_list!(run_time_options, :thermal_commitment)
    end

    @variable(
        model.jump_model,
        thermal_startup[b in subperiods(inputs), t in commitment_indexes],
        lower_bound = 0.0,
        upper_bound = 1.0,
    )

    @variable(
        model.jump_model,
        thermal_shutdown[b in subperiods(inputs), t in commitment_indexes],
        lower_bound = 0.0,
        upper_bound = 1.0,
    )

    if thermal_unit_intra_period_operation(inputs) ==
       Configurations_ThermalUnitIntraPeriodOperation.CYCLIC_WITH_FLEXIBLE_START
        # Add fictitious startup and shutdown variables to connect the last subperiod to the first subperiod
        @variable(
            model.jump_model,
            thermal_startup_loop[t in commitment_indexes],
            lower_bound = 0.0,
            upper_bound = 1.0,
        )
        @variable(
            model.jump_model,
            thermal_shutdown_loop[t in commitment_indexes],
            lower_bound = 0.0,
            upper_bound = 1.0,
        )
    end

    @expression(
        model.jump_model,
        thermal_startup_cost[b in subperiods(inputs), t in commitment_indexes],
        thermal_startup[b, t] * thermal_unit_startup_cost(inputs, t),
    )

    @expression(
        model.jump_model,
        thermal_shutdown_cost[b in subperiods(inputs), t in commitment_indexes],
        thermal_shutdown[b, t] * thermal_unit_shutdown_cost(inputs, t),
    )

    model.obj_exp +=
        sum(thermal_startup_cost) * money_to_thousand_money() + sum(thermal_shutdown_cost) * money_to_thousand_money()

    return nothing
end

function thermal_commitment!(
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
    thermal_commitment!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output file to store the thermal unit commitment variables' values.
"""
function thermal_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    thermal_units_with_commitment = index_of_elements_that_appear_at_some_point_in_study_horizon(
        inputs,
        ThermalUnit;
        run_time_options,
        filters = [has_commitment],
    )

    if run_time_options.clearing_model_subproblem != RunTime_ClearingSubproblem.EX_POST_COMMERCIAL
        add_symbol_to_query_from_subproblem_result!(outputs, :thermal_commitment)
        if use_binary_variables(inputs, run_time_options)
            add_symbol_to_serialize!(outputs, :thermal_commitment)
        end
    end

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "thermal_commitment",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "-",
        labels = thermal_unit_label(inputs)[thermal_units_with_commitment],
        run_time_options,
    )
    return nothing
end

"""
    thermal_commitment!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the thermal unit commitment variables' values to the output file.
"""
function thermal_commitment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    thermal_units_with_commitment = index_of_elements(
        inputs,
        ThermalUnit;
        run_time_options,
        filters = [has_commitment],
    )
    existing_thermal_units_with_commitment = index_of_elements(
        inputs,
        ThermalUnit;
        run_time_options,
        filters = [is_existing, has_commitment],
    )

    thermal_commitment = simulation_results.data[:thermal_commitment]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = thermal_units_with_commitment,
        elements_to_write = existing_thermal_units_with_commitment,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "thermal_commitment",
        thermal_commitment.data;
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
