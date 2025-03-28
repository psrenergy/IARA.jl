#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function flexible_demand_window_maximum_curtailment! end

"""
    flexible_demand_window_maximum_curtailment!(
        model,
        inputs,
        run_time_options,
        ::Type{SubproblemBuild},
    )

Add the flexible demand window maximum curtailment constraints to the model.
"""
function flexible_demand_window_maximum_curtailment!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    flexible_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_flexible])

    # Model Variables
    demand_curtailment = get_model_object(model, :demand_curtailment)

    # Model Parameters
    demand = get_model_object(model, :demand)

    # Constraints
    @constraint(
        model.jump_model,
        flexible_demand_window_maximum_curtailment[
            d in flexible_demands,
            w in 1:number_of_flexible_demand_windows(inputs, d),
        ],
        sum(
            demand_curtailment[b, d] * MW_to_GW()
            for b in subperiods_in_flexible_demand_window(inputs, d, w)
        ) <=
        demand_unit_max_curtailment(inputs, d) * sum(
            demand[b, d]
            for b in subperiods_in_flexible_demand_window(inputs, d, w)
        )
    )

    return nothing
end

function flexible_demand_window_maximum_curtailment!(
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

function flexible_demand_window_maximum_curtailment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function flexible_demand_window_maximum_curtailment!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
