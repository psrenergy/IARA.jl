#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function flexible_demand! end

function flexible_demand!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    flexible_demands = index_of_elements(inputs, Demand; filters = [is_existing, is_flexible])

    @variable(
        model.jump_model,
        attended_flexible_demand[
            b in blocks(inputs),
            d in flexible_demands,
        ],
        lower_bound = 0.0,
    ) # MWh

    @variable(
        model.jump_model,
        demand_curtailment[
            b in blocks(inputs),
            d in flexible_demands,
        ],
        lower_bound = 0.0,
    ) # MWh

    model.obj_exp = @expression(
        model.jump_model,
        model.obj_exp +
        money_to_thousand_money() * sum(
            demand_curtailment[b, d] * demand_curtailment_cost(inputs, d)
            for b in blocks(inputs), d in flexible_demands
        ),
    )

    return nothing
end

function flexible_demand!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function flexible_demand!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    flexible_demands = index_of_elements(inputs, Demand; run_time_options, filters = [is_flexible])

    add_symbol_to_query_from_subproblem_result!(outputs, [:attended_flexible_demand, :demand_curtailment])

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "attended_flexible_demand",
        dimensions = ["stage", "scenario", "block"],
        unit = "GWh",
        labels = demand_label(inputs)[flexible_demands],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "demand_curtailment",
        dimensions = ["stage", "scenario", "block"],
        unit = "GWh",
        labels = demand_label(inputs)[flexible_demands],
        run_time_options,
    )
    return nothing
end

function flexible_demand!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    flexible_demands = index_of_elements(inputs, Demand; run_time_options, filters = [is_flexible])
    existing_flexible_demands =
        index_of_elements(inputs, Demand; run_time_options, filters = [is_existing, is_flexible])

    attended_flexible_demand = simulation_results.data[:attended_flexible_demand]
    demand_curtailment = simulation_results.data[:demand_curtailment]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = flexible_demands,
        elements_to_write = existing_flexible_demands,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "attended_flexible_demand",
        attended_flexible_demand.data;
        stage,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "demand_curtailment",
        demand_curtailment.data;
        stage,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )

    return nothing
end
