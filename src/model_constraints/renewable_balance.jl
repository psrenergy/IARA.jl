#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function renewable_balance! end

function renewable_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    renewable_units = index_of_elements(inputs, RenewableUnit; run_time_options, filters = [is_existing])
    # Model Variables
    renewable_generation = get_model_object(model, :renewable_generation)
    renewable_curtailment = get_model_object(model, :renewable_curtailment)

    # Model parameters
    renewable_generation_scenario = get_model_object(model, :renewable_generation_scenario)

    # Constraints
    @constraint(
        model.jump_model,
        renewable_balance[b in subperiods(inputs), r in renewable_units],
        renewable_generation[b, r] + renewable_curtailment[b, r] ==
        renewable_unit_max_generation(inputs, r) * subperiod_duration_in_hours(inputs, b) *
        renewable_generation_scenario[b, r]
    )

    return nothing
end

function renewable_balance!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function renewable_balance!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function renewable_balance!(
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
