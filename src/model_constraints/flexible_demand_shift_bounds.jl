#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function flexible_demand_shift_bounds! end

"""
    flexible_demand_shift_bounds!(
        model,
        inputs,
        run_time_options,
        ::Type{SubproblemBuild},
    )

Add the flexible demand shift bounds constraints to the model.
"""
function flexible_demand_shift_bounds!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    flexible_demands = index_of_elements(inputs, DemandUnit; filters = [is_existing, is_flexible])

    # Model Variables
    attended_flexible_demand = get_model_object(model, :attended_flexible_demand)
    demand_curtailment = get_model_object(model, :demand_curtailment)

    # Model parameters
    demand = get_model_object(model, :demand)

    # Constraints
    @constraint(
        model.jump_model,
        flexible_demand_shift_up[b in subperiods(inputs), d in flexible_demands],
        attended_flexible_demand[b, d] + demand_curtailment[b, d] <=
        (1 + demand_unit_max_shift_up(inputs, d)) * demand[b, d] / MW_to_GW()
    )

    @constraint(
        model.jump_model,
        flexible_demand_shift_down[
            b in subperiods(inputs),
            d in flexible_demands,
        ],
        attended_flexible_demand[b, d] + demand_curtailment[b, d] >=
        (1 - demand_unit_max_shift_down(inputs, d)) * demand[b, d] / MW_to_GW()
    )

    return nothing
end

function flexible_demand_shift_bounds!(
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

function flexible_demand_shift_bounds!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function flexible_demand_shift_bounds!(
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
