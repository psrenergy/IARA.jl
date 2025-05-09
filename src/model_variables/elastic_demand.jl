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

"""
    elastic_demand!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the elastic demand variables to the model.
"""
function elastic_demand!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    existing_elastic_demand = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_elastic])

    # Time series
    elastic_demand_price_series = time_series_elastic_demand_price(inputs)

    # Variables
    @variable(
        model.jump_model,
        attended_elastic_demand[b in subperiods(inputs), d in existing_elastic_demand],
        lower_bound = 0.0,
    ) # MWh

    # Parameters

    if is_mincost(inputs) ||
       construction_type(inputs, run_time_options) == IARA.Configurations_ConstructionType.COST_BASED
        # This is only used in pure physical problems, when in bid-based problems
        # the price offer is set by the bidding group

        @variable(
            model.jump_model,
            elastic_demand_price[b in subperiods(inputs), d in existing_elastic_demand]
            in
            MOI.Parameter(
                elastic_demand_price_series[
                    index_among_elastic_demands(inputs, d),
                    b,
                ],
            )
        ) # $/MWh

        model.obj_exp = @expression(
            model.jump_model,
            model.obj_exp -
            money_to_thousand_money() * sum(
                attended_elastic_demand[b, d] * elastic_demand_price[b, d]
                for b in subperiods(inputs), d in existing_elastic_demand
            ),
        )
    end

    return nothing
end

"""
    elastic_demand!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, scenario, subscenario, ::Type{SubproblemUpdate})

Updates the elastic demand variables in the model.
"""
function elastic_demand!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    if !(
        is_mincost(inputs) ||
        construction_type(inputs, run_time_options) == IARA.Configurations_ConstructionType.COST_BASED
    )
        return nothing
    end
    existing_elastic_demand = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_elastic])

    # Model parameters
    elastic_demand_price = get_model_object(model, :elastic_demand_price)

    # Time series
    elastic_demand_price_series = time_series_elastic_demand_price(inputs)

    for b in subperiods(inputs), (i, d) in enumerate(existing_elastic_demand)
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            elastic_demand_price[b, d],
            elastic_demand_price_series[i, b],
        )
    end

    return nothing
end

"""
    elastic_demand!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output file to store the attended elastic demand.
"""
function elastic_demand!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    elastic_demands = index_of_elements_that_appear_at_some_point_in_study_horizon(
        inputs,
        DemandUnit;
        run_time_options,
        filters = [is_elastic],
    )

    add_symbol_to_query_from_subproblem_result!(outputs, :attended_elastic_demand)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "attended_elastic_demand",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "GWh",
        labels = demand_unit_label(inputs)[elastic_demands],
        run_time_options,
    )
    return nothing
end

"""
    elastic_demand!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the attended elastic demand to the output file.
"""
function elastic_demand!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    elastic_demands = index_of_elements(inputs, DemandUnit; run_time_options, filters = [is_elastic])
    existing_elastic_demands =
        index_of_elements(inputs, DemandUnit; run_time_options, filters = [is_existing, is_elastic])

    attended_elastic_demand = simulation_results.data[:attended_elastic_demand]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = elastic_demands,
        elements_to_write = existing_elastic_demands,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "attended_elastic_demand",
        attended_elastic_demand.data;
        period,
        scenario,
        subscenario,
        multiply_by = MW_to_GW(),
        indices_of_elements_in_output,
    )
    return nothing
end
