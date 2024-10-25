#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function hydro_minimum_outflow! end

function hydro_minimum_outflow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    minimum_outflow_indexes =
        index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing, has_min_outflow])

    # Model Variables
    hydro_turbining = get_model_object(model, :hydro_turbining)
    hydro_spillage = get_model_object(model, :hydro_spillage)
    hydro_minimum_outflow_slack = get_model_object(model, :hydro_minimum_outflow_slack)

    # Constraints
    @constraint(
        model.jump_model,
        hydro_minimum_outflow[
            b in subperiods(inputs),
            h in minimum_outflow_indexes,
        ],
        hydro_spillage[b, h] + hydro_turbining[b, h] + hydro_minimum_outflow_slack[b, h] >=
        hydro_unit_min_outflow(inputs, h) * m3_per_second_to_hm3_per_hour() * subperiod_duration_in_hours(inputs, b)
    )

    return nothing
end

function hydro_minimum_outflow!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function hydro_minimum_outflow!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function hydro_minimum_outflow!(
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
