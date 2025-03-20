#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function demand! end

"""
    demand!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the demand variables to the model.
"""
function demand!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    demands = index_of_elements(inputs, DemandUnit; filters = [is_existing])

    # Time series
    subscenario = 1 # placeholder as time-series data is replaced in SubproblemUpdate functions
    demand_ts = time_series_demand(inputs, run_time_options; subscenario)

    # Variables
    @variable(
        model.jump_model,
        deficit[blk in subperiods(inputs), d in demands],
        lower_bound = 0.0,
    ) # MWh

    # Parameters
    @variable(
        model.jump_model,
        demand[blk in subperiods(inputs), d in demands]
        in
        MOI.Parameter(
            demand_mw_to_gwh(
                inputs,
                demand_ts[d, blk],
                d,
                blk,
            ),
        )
    ) # GWh

    model.obj_exp = @expression(
        model.jump_model,
        model.obj_exp +
        money_to_thousand_money() * sum(
            deficit[blk, d] * demand_deficit_cost(inputs)
            for blk in subperiods(inputs), d in demands
        ),
    )

    return nothing
end

"""
    demand!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, scenario, subscenario, ::Type{SubproblemUpdate})

Updates the demand variables in the model.
"""
function demand!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    demands = index_of_elements(inputs, DemandUnit; filters = [is_existing])

    # Model parameters
    demand = get_model_object(model, :demand)

    # Time series
    demand_ts = time_series_demand(inputs, run_time_options; subscenario)

    for blk in subperiods(inputs), d in demands
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            demand[blk, d],
            demand_mw_to_gwh(
                inputs,
                demand_ts[d, blk],
                d,
                blk,
            ),
        )
    end

    return nothing
end

"""
    demand!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Initialize the output file to store the demand and deficit variables' values.
"""
function demand!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    demands = index_of_elements(inputs, DemandUnit; run_time_options)

    add_symbol_to_query_from_subproblem_result!(outputs, [:deficit, :demand])

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "deficit",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "GWh",
        labels = demand_unit_label(inputs)[demands],
        run_time_options,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "demand",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "GWh",
        labels = demand_unit_label(inputs)[demands],
        run_time_options,
    )

    return nothing
end

"""
    demand!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the demand and deficit variables' values to the output file.
"""
function demand!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    demands = index_of_elements(inputs, DemandUnit; run_time_options, filters = [is_existing])
    existing_demands = index_of_elements(inputs, DemandUnit; run_time_options, filters = [is_existing])

    deficit = simulation_results.data[:deficit]
    demand = simulation_results.data[:demand]

    indices_of_elements_in_output = find_indices_of_elements_to_write_in_output(;
        elements_in_output_file = demands,
        elements_to_write = existing_demands,
    )

    write_output_per_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "deficit",
        deficit.data;
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
        "demand",
        demand.data;
        period,
        scenario,
        subscenario,
        indices_of_elements_in_output,
    )

    return nothing
end
