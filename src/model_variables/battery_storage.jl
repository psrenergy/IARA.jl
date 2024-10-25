#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function battery_unit_storage! end

function battery_unit_storage!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    battery_units = index_of_elements(inputs, BatteryUnit; run_time_options, filters = [is_existing])

    @variable(
        model.jump_model,
        battery_unit_storage_state[bat in battery_units],
        SDDP.State,
        initial_value = battery_unit_initial_storage(inputs, bat),
        lower_bound = battery_unit_min_storage(inputs, bat),
        upper_bound = battery_unit_max_storage(inputs, bat),
    )

    battery_unit_subperiods = collect(1:number_of_subperiods(inputs)+1)

    @variable(
        model.jump_model,
        battery_unit_storage[b in battery_unit_subperiods, bat in battery_units],
        lower_bound = battery_unit_min_storage(inputs, bat),
        upper_bound = battery_unit_max_storage(inputs, bat),
    )

    model.obj_exp = @expression(
        model.jump_model,
        model.obj_exp +
        money_to_thousand_money() * sum(
            battery_unit_storage[subperiod, bat] * battery_unit_om_cost(inputs, bat)
            for subperiod in subperiods(inputs), bat in battery_units
        ),
    )

    return nothing
end

function battery_unit_storage!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function battery_unit_storage!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    battery_units = index_of_elements(inputs, BatteryUnit; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, :battery_unit_storage)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "battery_storage",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "GWh",
        labels = battery_unit_label(inputs)[battery_units],
        run_time_options,
    )
    return nothing
end

function battery_unit_storage!(
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

    battery_unit_storage = simulation_results.data[:battery_unit_storage]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = battery_units,
        elements_to_write = existing_battery_units,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "battery_storage",
        battery_unit_storage.data;
        period,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )

    return nothing
end
