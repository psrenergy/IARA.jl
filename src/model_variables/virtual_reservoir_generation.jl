#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function virtual_reservoir_generation! end

"""
    virtual_reservoir_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{SubproblemBuild})

Add the virtual reservoir generation variables to the model.
"""
function virtual_reservoir_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{SubproblemBuild},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    valid_segments = get_maximum_valid_virtual_reservoir_segments(inputs)

    # Time series
    placeholder_virtual_reservoir_quantity_offer_series = 0.0
    placeholder_virtual_reservoir_price_offer_series = 0.0

    # Parameters
    @variable(
        model.jump_model,
        virtual_reservoir_quantity_offer[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
            seg in 1:valid_segments[vr],
        ]
        in
        MOI.Parameter(placeholder_virtual_reservoir_quantity_offer_series)
    ) # MWh
    @variable(
        model.jump_model,
        virtual_reservoir_price_offer[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
            seg in 1:valid_segments[vr],
        ]
        in
        MOI.Parameter(placeholder_virtual_reservoir_price_offer_series)
    ) # $/MWh

    # Variables
    @variable(
        model.jump_model,
        virtual_reservoir_generation[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
            seg in 1:valid_segments[vr],
        ],
        lower_bound = 0.0,
    ) # MWh

    # Objective function
    @expression(
        model.jump_model,
        accepted_virtual_reservoir_offers_cost[
            vr in virtual_reservoirs,
            ao in virtual_reservoir_asset_owner_indices(inputs, vr),
            seg in 1:valid_segments[vr],
        ],
        virtual_reservoir_generation[vr, ao, seg] * virtual_reservoir_price_offer[vr, ao, seg],
    )

    model.obj_exp += sum(accepted_virtual_reservoir_offers_cost) * money_to_thousand_money()

    return nothing
end

"""
    virtual_reservoir_generation!(model::SubproblemModel, inputs::Inputs, run_time_options::RunTimeOptions, scenario, subscenario, ::Type{SubproblemUpdate})

Update the virtual reservoir generation variables in the model.
"""
function virtual_reservoir_generation!(
    model::SubproblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{SubproblemUpdate},
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    valid_segments = get_maximum_valid_virtual_reservoir_segments(inputs)

    # Model parameters
    virtual_reservoir_quantity_offer = get_model_object(model, :virtual_reservoir_quantity_offer)
    virtual_reservoir_price_offer = get_model_object(model, :virtual_reservoir_price_offer)

    # Time series
    virtual_reservoir_quantity_offer_series =
        time_series_virtual_reservoir_quantity_offer(inputs, model.node, scenario)
    virtual_reservoir_price_offer_series = time_series_virtual_reservoir_price_offer(inputs, model.node, scenario)

    for vr in virtual_reservoirs, ao in virtual_reservoir_asset_owner_indices(inputs, vr), seg in 1:valid_segments[vr]
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            virtual_reservoir_quantity_offer[vr, ao, seg],
            virtual_reservoir_quantity_offer_series[vr, ao, seg],
        )
        MOI.set(
            model.jump_model,
            POI.ParameterValue(),
            virtual_reservoir_price_offer[vr, ao, seg],
            virtual_reservoir_price_offer_series[vr, ao, seg],
        )
    end
    return nothing
end

"""
    virtual_reservoir_generation!(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, ::Type{InitializeOutput})

Add symbols to serialize and query the virtual reservoir generation variables and initialize the output file for virtual reservoir generation.
"""
function virtual_reservoir_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    ::Type{InitializeOutput},
)
    add_symbol_to_query_from_subproblem_result!(outputs, :virtual_reservoir_generation)

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "virtual_reservoir_generation",
        dimensions = ["period", "scenario", "bid_segment"],
        unit = "GWh",
        labels = labels_for_output_by_pair_of_agents(
            inputs,
            run_time_options,
            inputs.collections.virtual_reservoir,
            inputs.collections.asset_owner;
            index_getter = virtual_reservoir_asset_owner_indices,
        ),
        run_time_options,
    )
    return nothing
end

"""
    virtual_reservoir_generation!(outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario, period::Int, scenario::Int, subscenario::Int, ::Type{WriteOutput})

Write the virtual reservoir generation variables' values to the output file.
"""
function virtual_reservoir_generation!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
    subscenario::Int,
    ::Type{WriteOutput},
)
    number_of_segments = maximum_number_of_virtual_reservoir_bidding_segments(inputs)
    treated_virtual_reservoir_generation = treat_output_for_writing_by_pairs_of_agents(
        inputs,
        run_time_options,
        simulation_results.data[:virtual_reservoir_generation],
        inputs.collections.virtual_reservoir,
        inputs.collections.asset_owner;
        index_getter = virtual_reservoir_asset_owner_indices,
        output_varies_per_subperiod = false,
    )

    output = outputs.outputs["virtual_reservoir_generation"*run_time_file_suffixes(inputs, run_time_options)]
    if is_ex_post_problem(run_time_options)
        for bid_segment in 1:number_of_segments
            Quiver.write!(
                output.writer,
                round_output(treated_virtual_reservoir_generation[:, bid_segment] * MW_to_GW());
                period, scenario, subscenario, bid_segment,
            )
        end
    else
        for bid_segment in 1:number_of_segments
            Quiver.write!(
                output.writer,
                round_output(treated_virtual_reservoir_generation[:, bid_segment] * MW_to_GW());
                period, scenario, bid_segment,
            )
        end
    end
    return nothing
end
