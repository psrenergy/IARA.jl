#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_volume_distance_to_waveguide! end

"""
    virtual_reservoir_volume_distance_to_waveguide!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the virtual reservoir volume distance to waveguide constraints to the model.
"""
function virtual_reservoir_volume_distance_to_waveguide!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    hydro_volume = get_model_object(model, :hydro_volume) # [b in hydro_subperiods, h in hydro_units]
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    @variable(
        model.jump_model,
        waveguide_convex_combination_factor[vr in virtual_reservoirs, p in 1:number_of_waveguide_points(inputs, vr)],
        lower_bound = 0,
        upper_bound = 1,
    )

    @variable(
        model.jump_model,
        hydro_volume_distance_to_waveguide[
            vr in virtual_reservoirs,
            h in virtual_reservoir_hydro_unit_indices(inputs, vr),
        ],
        lower_bound = 0.0,
    )

    # Objective function
    model.obj_exp = @expression(
        model.jump_model,
        model.obj_exp +
        money_to_thousand_money() * sum(hydro_volume_distance_to_waveguide) * 1e-3,
    )

    return nothing
end

function virtual_reservoir_volume_distance_to_waveguide!(
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

function virtual_reservoir_volume_distance_to_waveguide!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_volume_distance_to_waveguide!(
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
