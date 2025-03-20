#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function waveguide_distance_bounds! end

"""
    waveguide_distance_bounds!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the waveguide distance bounds constraints to the model.
"""
function waveguide_distance_bounds!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    waveguide_convex_combination_factor = get_model_object(model, :waveguide_convex_combination_factor)
    hydro_volume = get_model_object(model, :hydro_volume)
    hydro_volume_distance_to_waveguide = get_model_object(model, :hydro_volume_distance_to_waveguide)

    @constraint(
        model.jump_model,
        waveguide_distance_first_bound[
            vr in virtual_reservoirs,
            h in virtual_reservoir_hydro_unit_indices(inputs, vr),
        ],
        hydro_volume_distance_to_waveguide[vr, h] >=
        hydro_volume[end, h]
        -
        sum(
            waveguide_convex_combination_factor[vr, p] * virtual_reservoir_waveguide_points(inputs, vr)[h, p]
            for p in 1:number_of_waveguide_points(inputs, vr)
        )
    )

    @constraint(
        model.jump_model,
        waveguide_distance_second_bound[
            vr in virtual_reservoirs,
            h in virtual_reservoir_hydro_unit_indices(inputs, vr),
        ],
        hydro_volume_distance_to_waveguide[vr, h] >=
        sum(
            waveguide_convex_combination_factor[vr, p] * virtual_reservoir_waveguide_points(inputs, vr)[h, p]
            for p in 1:number_of_waveguide_points(inputs, vr)
        )
        -
        hydro_volume[end, h]
    )

    return nothing
end

function waveguide_distance_bounds!(
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

function waveguide_distance_bounds!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function waveguide_distance_bounds!(
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
