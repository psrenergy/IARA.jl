#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_generation_bounds_values! end

function virtual_reservoir_generation_bounds_values!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    valid_segments = get_maximum_valid_virtual_reservoir_segments(inputs)

    placeholder_upper_bound = 0.0
    placeholder_lower_bound = 0.0

    @variable(
        model.jump_model,
        virtual_reservoir_generation_upper_bound_value[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
            seg in 1:valid_segments[vr],
        ]
        in
        MOI.Parameter(placeholder_upper_bound)
    ) # MWh

    @variable(
        model.jump_model,
        virtual_reservoir_generation_lower_bound_value[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
            seg in 1:valid_segments[vr],
        ]
        in
        MOI.Parameter(placeholder_lower_bound)
    ) # MWh

    return nothing
end

function virtual_reservoir_generation_bounds_values!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_period::Int,
    simulation_trajectory::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    valid_segments = get_maximum_valid_virtual_reservoir_segments(inputs)

    # Time series
    virtual_reservoir_quantity_offer_series =
        time_series_virtual_reservoir_quantity_offer(inputs, model.node, scenario)

    # Variables
    virtual_reservoir_generation_upper_bound_value =
        get_model_object(model, :virtual_reservoir_generation_upper_bound_value)
    virtual_reservoir_generation_lower_bound_value =
        get_model_object(model, :virtual_reservoir_generation_lower_bound_value)

    for vr in virtual_reservoirs, ao in virtual_reservoir_asset_owner_indices(inputs, vr), seg in 1:valid_segments[vr]
        if virtual_reservoir_quantity_offer_series[vr, ao, seg] >= 0.0
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                virtual_reservoir_generation_upper_bound_value[vr, ao, seg],
                virtual_reservoir_quantity_offer_series[vr, ao, seg],
            )
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                virtual_reservoir_generation_lower_bound_value[vr, ao, seg],
                0.0,
            )
        else
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                virtual_reservoir_generation_upper_bound_value[vr, ao, seg],
                0.0,
            )
            MOI.set(
                model.jump_model,
                POI.ParameterValue(),
                virtual_reservoir_generation_lower_bound_value[vr, ao, seg],
                virtual_reservoir_quantity_offer_series[vr, ao, seg],
            )
        end
    end
    return nothing
end

function virtual_reservoir_generation_bounds_values!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_generation_bounds_values!(
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
