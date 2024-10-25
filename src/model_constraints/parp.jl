#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function parp! end

function parp!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])

    # Model variables
    normalized_inflow = get_model_object(model, :normalized_inflow)

    # Model parameters
    inflow_noise = get_model_object(model, :inflow_noise)

    # Model constraints
    @constraint(
        model.jump_model,
        update_inflow_state[
            h in hydro_units,
            tau in 1:(parp_max_lags(inputs)-1),
        ],
        normalized_inflow[h, tau].out == normalized_inflow[h, tau+1].in
    )
    @constraint(
        model.jump_model,
        parp[h in hydro_units],
        normalized_inflow[h, end].out ==
        sum(
            time_series_parp_coefficients(inputs)[
                hydro_unit_gauging_station_index(inputs, h),
                parp_max_lags(inputs)-tau+1,
            ] * normalized_inflow[h, tau].in for tau in 1:parp_max_lags(inputs)
        ) + inflow_noise[h]
    )

    return nothing
end

function parp!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    return nothing
end

function parp!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function parp!(
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
