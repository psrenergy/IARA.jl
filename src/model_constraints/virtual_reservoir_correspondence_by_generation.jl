#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_correspondence_by_generation! end

"""
    virtual_reservoir_correspondence_by_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the virtual reservoir correspondence by generation constraints to the model.
"""
function virtual_reservoir_correspondence_by_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    # Model variables
    virtual_reservoir_generation = get_model_object(model, :virtual_reservoir_generation)
    hydro_turbining = get_model_object(model, :hydro_turbining)
    hydro_spillage = get_model_object(model, :hydro_spillage)
    valid_segments = get_maximum_valid_virtual_reservoir_segments(inputs)

    # Model constraints
    @constraint(
        model.jump_model,
        virtual_reservoir_generation_balance[vr in virtual_reservoirs],
        sum(
            (hydro_turbining[b, h] + hydro_spillage[b, h]) * hydro_unit_production_factor(inputs, h) /
            m3_per_second_to_hm3_per_hour()
            for b in subperiods(inputs), h in virtual_reservoir_hydro_unit_indices(inputs, vr)
        ) == sum(
            virtual_reservoir_generation[vr, ao, seg] for ao in virtual_reservoir_asset_owner_indices(inputs, vr),
            seg in 1:valid_segments[vr]
        )
    )

    return nothing
end

function virtual_reservoir_correspondence_by_generation!(
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

function virtual_reservoir_correspondence_by_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    return nothing
end

function virtual_reservoir_correspondence_by_generation!(
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
