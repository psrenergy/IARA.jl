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
    number_of_virtual_reservoirs = number_of_elements(inputs, VirtualReservoir)

    # Model variables
    virtual_reservoir_generation = get_model_object(model, :virtual_reservoir_generation)
    hydro_turbining = get_model_object(model, :hydro_turbining)
    hydro_spillage = get_model_object(model, :hydro_spillage)

    # Model constraints
    @constraint(
        model.jump_model,
        virtual_reservoir_generation_balance[vr in 1:number_of_virtual_reservoirs],
        sum(
            (hydro_turbining[b, h] + hydro_spillage[b, h]) * hydro_unit_production_factor(inputs, h) /
            m3_per_second_to_hm3_per_hour()
            for b in subperiods(inputs), h in virtual_reservoir_hydro_unit_indices(inputs, vr)
        ) == sum(
            virtual_reservoir_generation[vr, ao, seg] for ao in virtual_reservoir_asset_owner_indices(inputs, vr),
            seg in 1:number_of_vr_valid_bidding_segments(inputs, vr)
        )
    )

    return nothing
end

function virtual_reservoir_correspondence_by_generation!(
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

function virtual_reservoir_correspondence_by_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    add_custom_recorder_to_query_from_subproblem_result!(
        outputs,
        :virtual_reservoir_marginal_cost,
        constraint_dual_recorder(inputs, :virtual_reservoir_generation_balance),
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "virtual_reservoir_marginal_cost",
        dimensions = ["period", "scenario"],
        unit = "\$/MWh",
        labels = virtual_reservoir_label(inputs),
        run_time_options,
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
    virtual_reservoir_marginal_cost = simulation_results.data[:virtual_reservoir_marginal_cost]

    write_output_without_subperiod!(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_marginal_cost",
        virtual_reservoir_marginal_cost;
        period = period,
        scenario = scenario,
        subscenario = subscenario,
        multiply_by = -1 / money_to_thousand_money(),
    )

    return nothing
end
