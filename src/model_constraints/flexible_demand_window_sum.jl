#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function flexible_demand_window_sum! end

"""
    flexible_demand_window_sum!(
        model,
        inputs,
        run_time_options,
        ::Type{SubproblemBuild},
    )

Add the flexible demand window sum constraints to the model.
"""
function flexible_demand_window_sum!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    flexible_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_flexible])

    # Model Variables
    attended_flexible_demand = get_model_object(model, :attended_flexible_demand)
    demand_curtailment = get_model_object(model, :demand_curtailment)
    deficit = get_model_object(model, :deficit)

    # Model Parameters
    demand = get_model_object(model, :demand)

    # Constraints
    @constraint(
        model.jump_model,
        flexible_demand_window_sum[
            d in flexible_demands,
            w in 1:number_of_flexible_demand_windows(inputs, d),
        ],
        sum(
            attended_flexible_demand[b, d] + demand_curtailment[b, d] + deficit[b, d]
            for b in subperiods_in_flexible_demand_window(inputs, d, w)
        ) * MW_to_GW() ==
        sum(
            demand[b, d]
            for b in subperiods_in_flexible_demand_window(inputs, d, w)
        )
    )

    return nothing
end

function flexible_demand_window_sum!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function flexible_demand_window_sum!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function flexible_demand_window_sum!(
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
