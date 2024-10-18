#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function elastic_demand! end

function elastic_demand!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    existing_elastic_demand = index_of_elements(inputs, Demand; filters = [is_existing, is_elastic])

    # Time series
    elastic_demand_price_series = time_series_elastic_demand_price(inputs)

    # Variables
    @variable(
        model.jump_model,
        attended_elastic_demand[b in blocks(inputs), d in existing_elastic_demand],
        lower_bound = 0.0,
    ) # MWh

    # Parameters

    @variable(
        model.jump_model,
        elastic_demand_price[b in blocks(inputs), d in existing_elastic_demand]
        in
        MOI.Parameter(
            elastic_demand_price_series[
                index_among_elastic_demands(inputs, d),
                b,
            ],
        )
    ) # $/MWh

    # Objective function
    model.obj_exp = @expression(
        model.jump_model,
        model.obj_exp -
        money_to_thousand_money() * sum(
            attended_elastic_demand[b, d] * elastic_demand_price[b, d]
            for b in blocks(inputs), d in existing_elastic_demand
        ),
    )

    return nothing
end

function elastic_demand!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    existing_elastic_demand = index_of_elements(inputs, Demand; filters = [is_existing, is_elastic])

    # Model parameters
    elastic_demand_price = get_model_object(model, :elastic_demand_price)

    # Time series
    elastic_demand_price_series = time_series_elastic_demand_price(inputs)

    for b in blocks(inputs), (i, d) in enumerate(existing_elastic_demand)
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            elastic_demand_price[b, d],
            elastic_demand_price_series[i, b],
        )
    end

    return nothing
end

function elastic_demand!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    elastic_demands = index_of_elements(inputs, Demand; run_time_options, filters = [is_elastic])

    add_symbol_to_query_from_subproblem_result!(outputs, :attended_elastic_demand)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "attended_elastic_demand",
        dimensions = ["stage", "scenario", "block"],
        unit = "GWh",
        labels = demand_label(inputs)[elastic_demands],
        run_time_options,
    )
    return nothing
end

function elastic_demand!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    elastic_demands = index_of_elements(inputs, Demand; run_time_options, filters = [is_elastic])
    existing_elastic_demands = index_of_elements(inputs, Demand; run_time_options, filters = [is_existing, is_elastic])

    attended_elastic_demand = simulation_results.data[:attended_elastic_demand]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = elastic_demands,
        elements_to_write = existing_elastic_demands,
    )

    write_output_per_block!(
        outputs,
        inputs,
        run_time_options,
        "attended_elastic_demand",
        attended_elastic_demand.data;
        stage,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )
    return nothing
end