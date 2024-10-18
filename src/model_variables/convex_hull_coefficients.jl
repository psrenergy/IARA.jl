#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function convex_hull_coefficients! end

function convex_hull_coefficients!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    # Maximum number of points (across scenarios) in the convex hull for each bus and block
    max_convex_hull_length =
        zeros(Int, length(buses_represented_for_strategic_bidding(inputs)), number_of_blocks(inputs))
    for scenario in scenarios(inputs)
        update_time_series_views_from_external_files!(inputs; stage = model.stage, scenario)
        update_convex_hull_cache!(inputs, run_time_options)
        updated_convex_hull = asset_owner_revenue_convex_hull(inputs)
        max_convex_hull_length = max.(max_convex_hull_length, length.(updated_convex_hull))
    end

    # Variables
    @variable(
        model.jump_model,
        convex_revenue_coefficients[
            block in blocks(inputs),
            bus in buses_represented_for_strategic_bidding(inputs),
            v in 1:max_convex_hull_length[bus, block],
        ],
        lower_bound = 0.0,
        upper_bound = 1.0,
    )

    # Parameters
    @variable(
        model.jump_model,
        convex_hull_point_quantity[
            block in blocks(inputs),
            bus in buses_represented_for_strategic_bidding(inputs),
            v in 1:max_convex_hull_length[bus, block],
        ]
        in
        MOI.Parameter(asset_owner_revenue_convex_hull_point(inputs, bus, block, v).x),
    )

    @variable(
        model.jump_model,
        convex_hull_point_revenue[
            block in blocks(inputs),
            bus in buses_represented_for_strategic_bidding(inputs),
            v in 1:max_convex_hull_length[bus, block],
        ]
        in
        MOI.Parameter(asset_owner_revenue_convex_hull_point(inputs, bus, block, v).y),
    )

    # Objective function
    @expression(
        model.jump_model,
        asset_owner_revenue[
            block in blocks(inputs),
            bus in buses_represented_for_strategic_bidding(inputs),
        ],
        -sum(
            convex_revenue_coefficients[block, bus, v]
            *
            convex_hull_point_revenue[block, bus, v]
            for v in 1:max_convex_hull_length[bus, block]
        ),
    )

    model.obj_exp += sum(asset_owner_revenue) * money_to_thousand_money()

    return nothing
end

function convex_hull_coefficients!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    update_convex_hull_cache!(inputs, run_time_options)

    # Number of points in the convex hull for each bus and block
    convex_hull_length = length.(asset_owner_revenue_convex_hull(inputs))

    # Model parameters
    convex_hull_point_quantity = get_model_object(model, :convex_hull_point_quantity)
    convex_hull_point_revenue = get_model_object(model, :convex_hull_point_revenue)

    for block in blocks(inputs), bus in buses_represented_for_strategic_bidding(inputs),
        v in 1:convex_hull_length[bus, block]

        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            convex_hull_point_quantity[block, bus, v],
            asset_owner_revenue_convex_hull_point(inputs, bus, block, v).x,
        )
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            convex_hull_point_revenue[block, bus, v],
            asset_owner_revenue_convex_hull_point(inputs, bus, block, v).y,
        )
    end

    return nothing
end

function convex_hull_coefficients!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function convex_hull_coefficients!(
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
