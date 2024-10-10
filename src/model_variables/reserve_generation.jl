#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function reserve_generation! end

function reserve_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    reserves = index_of_elements(inputs, Reserve)
    num_reserves_associated_with_thermal_plants = number_of_elements(inputs, Reserve; filters = [has_thermal_plant])
    num_reserves_associated_with_hydro_plants = number_of_elements(inputs, Reserve; filters = [has_hydro_plant])
    num_reserves_associated_with_batteries = number_of_elements(inputs, Reserve; filters = [has_battery])

    # Time Series
    reserve_requirement_series = time_series_reserve_requirement(inputs)

    # Parameters
    @variable(
        model.jump_model,
        reserve_requirement[b in blocks(inputs), r in reserves]
        in
        MOI.Parameter(reserve_requirement_series[r, b])
    )

    # Variables
    @variable(
        model.jump_model,
        reserve_violation[b in blocks(inputs), r in reserves],
        lower_bound = 0.0,
    )

    if num_reserves_associated_with_thermal_plants > 0
        @variable(
            model.jump_model,
            reserve_generation_in_thermal_plant[
                b in blocks(inputs),
                r in reserves,
                j in reserve_thermal_plant_indices(inputs, r),
            ],
            lower_bound = 0.0,
        )
    end

    if num_reserves_associated_with_hydro_plants > 0
        @variable(
            model.jump_model,
            reserve_generation_in_hydro_plant[
                b in blocks(inputs),
                r in reserves,
                j in reserve_hydro_plant_indices(inputs, r),
            ],
            lower_bound = 0.0,
        )
    end

    if num_reserves_associated_with_batteries > 0
        @variable(
            model.jump_model,
            reserve_generation_in_battery[
                b in blocks(inputs),
                r in reserves,
                j in reserve_battery_indices(inputs, r),
            ],
            lower_bound = 0.0,
        )
    end

    # Objective function
    model.obj_exp = @expression(
        model.jump_model,
        model.obj_exp +
        money_to_thousand_money() * sum(
            reserve_violation[b, r] * reserve_violation_cost(inputs, r)
            for b in blocks(inputs), r in reserves
        ),
    )

    return nothing
end

function reserve_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    reserves = index_of_elements(inputs, Reserve)

    # Model parameters
    reserve_requirement = get_model_object(model, :reserve_requirement)

    # Time Series
    reserve_requirement_series = time_series_reserve_requirement(inputs)

    for b in blocks(inputs), r in reserves
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            reserve_requirement[b, r],
            reserve_requirement_series[r, b],
        )
    end

    return nothing
end

function reserve_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    any_reserves_associated_with_thermal_plants = any_elements(inputs, Reserve; filters = [has_thermal_plant])
    any_reserves_associated_with_hydro_plants = any_elements(inputs, Reserve; filters = [has_hydro_plant])
    any_reserves_associated_with_batteries = any_elements(inputs, Reserve; filters = [has_battery])

    add_symbol_to_query_from_subproblem_result!(outputs, :reserve_violation)
    if any_reserves_associated_with_thermal_plants
        add_symbol_to_query_from_subproblem_result!(outputs, :reserve_generation_in_thermal_plant)
    end
    if any_reserves_associated_with_hydro_plants
        add_symbol_to_query_from_subproblem_result!(outputs, :reserve_generation_in_hydro_plant)
    end
    if any_reserves_associated_with_batteries
        add_symbol_to_query_from_subproblem_result!(outputs, :reserve_generation_in_battery)
    end

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "reserve_violation",
        dimensions = ["stage", "scenario", "block"],
        unit = "GWh",
        labels = reserve_label(inputs),
        run_time_options,
    )

    if any_reserves_associated_with_thermal_plants
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "reserve_generation_in_thermal_plant",
            dimensions = ["stage", "scenario", "block"],
            unit = "GWh",
            labels = labels_for_output_by_pair_of_agents(
                inputs,
                run_time_options,
                inputs.collections.reserve,
                inputs.collections.thermal_plant;
                index_getter = reserve_thermal_plant_indices,
            ),
            run_time_options,
        )
    end

    if any_reserves_associated_with_hydro_plants
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "reserve_generation_in_hydro_plant",
            dimensions = ["stage", "scenario", "block"],
            unit = "GWh",
            labels = labels_for_output_by_pair_of_agents(
                inputs,
                run_time_options,
                inputs.collections.reserve,
                inputs.collections.hydro_plant;
                index_getter = reserve_hydro_plant_indices,
            ),
            run_time_options,
        )
    end

    if any_reserves_associated_with_batteries
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "reserve_generation_in_battery",
            dimensions = ["stage", "scenario", "block"],
            unit = "GWh",
            labels = labels_for_output_by_pair_of_agents(
                inputs,
                run_time_options,
                inputs.collections.reserve,
                inputs.collections.battery;
                index_getter = reserve_battery_indices,
            ),
            run_time_options,
        )
    end

    return nothing
end

function reserve_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    reserves = index_of_elements(inputs, Reserve)

    num_reserves_associated_with_thermal_plants = number_of_elements(inputs, Reserve; filters = [has_thermal_plant])
    num_reserves_associated_with_hydro_plants = number_of_elements(inputs, Reserve; filters = [has_hydro_plant])
    num_reserves_associated_with_batteries = number_of_elements(inputs, Reserve; filters = [has_battery])

    reserve_violation = simulation_results.data[:reserve_violation]

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "reserve_violation",
        reserve_violation.data;
        stage,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
    )

    if num_reserves_associated_with_thermal_plants > 0
        treated_reserve_generation_in_thermal_plant = treat_output_for_writing_by_pairs_of_agents(
            inputs,
            run_time_options,
            simulation_results.data[:reserve_generation_in_thermal_plant],
            inputs.collections.reserve,
            inputs.collections.thermal_plant;
            index_getter = reserve_thermal_plant_indices,
        )

        write_output_per_block!(
            outputs,
            inputs,
            run_time_options,
            "reserve_generation_in_thermal_plant",
            treated_reserve_generation_in_thermal_plant;
            stage,
            scenario,
            subscenario,
            multiply_by = MW_to_GW(),
        )
    end

    if num_reserves_associated_with_hydro_plants > 0
        treated_reserve_generation_in_hydro_plant = treat_output_for_writing_by_pairs_of_agents(
            inputs,
            run_time_options,
            simulation_results.data[:reserve_generation_in_hydro_plant],
            inputs.collections.reserve,
            inputs.collections.hydro_plant;
            index_getter = reserve_hydro_plant_indices,
        )

        write_output_per_block!(
            outputs,
            inputs,
            run_time_options,
            "reserve_generation_in_hydro_plant",
            treated_reserve_generation_in_hydro_plant;
            stage,
            scenario,
            subscenario,
            multiply_by = MW_to_GW(),
        )
    end

    if num_reserves_associated_with_batteries > 0
        treated_reserve_generation_in_battery = treat_output_for_writing_by_pairs_of_agents(
            inputs,
            run_time_options,
            simulation_results.data[:reserve_generation_in_battery],
            inputs.collections.reserve,
            inputs.collections.battery;
            index_getter = reserve_battery_indices,
        )

        write_output_per_block!(
            outputs,
            inputs,
            run_time_options,
            "reserve_generation_in_battery",
            treated_reserve_generation_in_battery;
            stage,
            scenario,
            subscenario,
            multiply_by = MW_to_GW(),
        )
    end

    return nothing
end
