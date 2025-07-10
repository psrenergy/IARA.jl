#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function battery_unit_generation! end

"""
    battery_unit_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the battery unit generation variables to the model.
"""
function battery_unit_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    battery_units = index_of_elements(inputs, BatteryUnit; run_time_options, filters = [is_existing])

    @variable(
        model.jump_model,
        battery_unit_generation[subperiod in subperiods(inputs), bat in battery_units],
        lower_bound = -battery_unit_max_capacity(inputs, bat) * subperiod_duration_in_hours(inputs, subperiod),
        upper_bound = battery_unit_max_capacity(inputs, bat) * subperiod_duration_in_hours(inputs, subperiod),
    )

    return nothing
end

function battery_unit_generation!(
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
    battery_unit_generation!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output file to store the battery unit generation variables' values.
"""
function battery_unit_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    battery_units = index_of_elements(inputs, BatteryUnit; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :battery_unit_generation)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "battery_generation",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "MW",
        labels = battery_unit_label(inputs)[battery_units],
        run_time_options,
    )

    return nothing
end

"""
    battery_unit_generation!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the battery unit generation variables' values to the output.
"""
function battery_unit_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    battery_units = index_of_elements(inputs, BatteryUnit; run_time_options)
    existing_battery_units = index_of_elements(inputs, BatteryUnit; run_time_options, filters = [is_existing])

    battery_unit_generation = simulation_results.data[:battery_unit_generation]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = battery_units,
        elements_to_write = existing_battery_units,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "battery_generation",
        battery_unit_generation.data;
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
        divide_by_subperiod_duration_in_hours = true,
    )

    return nothing
end
