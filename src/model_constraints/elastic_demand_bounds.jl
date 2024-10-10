#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function elastic_demand_bounds! end

function elastic_demand_bounds!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    elastic_demands = index_of_elements(inputs, Demand; filters = [is_existing, is_elastic])

    # Model Variables
    attended_elastic_demand = get_model_object(model, :attended_elastic_demand)

    # Model parameters
    demand = get_model_object(model, :demand)

    # Constraints
    @constraint(
        model.jump_model,
        attended_elastic_demand_upper_bound[
            block in blocks(inputs),
            d in elastic_demands,
        ],
        attended_elastic_demand[block, d] * MW_to_GW() <= demand[block, d],
    )

    return nothing
end

function elastic_demand_bounds!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function elastic_demand_bounds!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function elastic_demand_bounds!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario,
    stage::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    return nothing
end
