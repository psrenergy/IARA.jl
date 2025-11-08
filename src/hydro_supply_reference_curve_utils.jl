#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function is_reference_curve(inputs::Inputs, run_time_options::RunTimeOptions)
    return run_time_options.is_reference_curve
end

function reference_curve_multipliers(inputs::Inputs)
    all_multipliers = range(0.0, 1.0; length = reference_curve_number_of_segments(inputs) + 1)
    # Remove the first multiplier, which is always 0.0
    return all_multipliers[2:end]
end

function update_virtual_reservoir_reference_multiplier!(
    model::ProblemModel,
    inputs::Inputs,
    reference_multiplier::Float64,
    period::Int,
)
    # In cyclic policy graphs, this multiplier must be set for all nodes
    subproblem_models = if cyclic_policy_graph(inputs)
        [model.policy_graph[node].subproblem for node in 1:number_of_nodes(inputs)]
    else
        [model.policy_graph[period].subproblem]
    end

    # Model parameters
    for subproblem_model in subproblem_models
        virtual_reservoir_reference_multiplier =
            get_model_object(subproblem_model, :virtual_reservoir_reference_multiplier)

        MOI.set(
            subproblem_model,
            POI.ParameterValue(),
            virtual_reservoir_reference_multiplier,
            reference_multiplier,
        )
    end
    return nothing
end

function initialize_reference_curve_outputs(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    outputs = Outputs()

    add_custom_recorder_to_query_from_subproblem_result!(
        outputs,
        :virtual_reservoir_reference_price,
        constraint_dual_recorder(inputs, :virtual_reservoir_generation_reference),
    )

    add_symbol_to_query_from_subproblem_result!(
        outputs,
        :virtual_reservoir_total_generation,
    )

    add_symbol_to_query_from_subproblem_result!(
        outputs,
        :virtual_reservoir_available_energy,
    )

    add_symbol_to_query_from_subproblem_result!(
        outputs,
        :inflow_slack,
    )

    # Outputs
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_reference_curve_quantity",
        dimensions = ["period", "reference_curve_segment", "scenario"],
        unit = "GWh",
        labels = virtual_reservoir_label(inputs),
        run_time_options,
    )
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "hydro_reference_curve_price",
        dimensions = ["period", "reference_curve_segment", "scenario"],
        unit = "\$/MWh",
        labels = virtual_reservoir_label(inputs),
        run_time_options,
    )

    return outputs
end

function post_process_reference_curve_outputs(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::IARA.SimulationResultsFromPeriodScenario,
    period::Int,
    scenario::Int,
)
    number_of_virtual_reservoirs = number_of_elements(inputs, VirtualReservoir)

    # Simulation results
    quantity = simulation_results.data[:virtual_reservoir_total_generation].data
    price = simulation_results.data[:virtual_reservoir_reference_price]
    inflow_slack = simulation_results.data[:inflow_slack].data

    # Read serialized reference curve
    reference_quantity, reference_price = read_serialized_reference_curve(inputs, period, scenario)

    # Convert price in k$/MWh to $/MWh
    price /= money_to_thousand_money()
    price = zeros(number_of_virtual_reservoirs) .+ price

    if any(price .> demand_deficit_cost(inputs))
        subscenario = 1 # The reference curve model has no subscenario dimension
        # If the problem is infeasible, use the total virtual reservoir energy
        quantity = virtual_reservoir_stored_energy(
            inputs,
            run_time_options,
            period,
            scenario,
            subscenario,
        )
        # If the problem is infeasible, use the last price and add a markup
        price = if isempty(reference_price)
            ones(number_of_virtual_reservoirs) .* demand_deficit_cost(inputs) * (1.0 + reference_curve_final_segment_price_markup(inputs))
        else
            ones(number_of_virtual_reservoirs) .* reference_price[end] * (1.0 + reference_curve_final_segment_price_markup(inputs))
        end
    end

    # Get segment size from absolute quantity
    quantity .-= sum_previous_reference_curve_quantities(
        inputs,
        reference_quantity,
    )

    return quantity, price
end

function write_reference_curve_outputs(
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    simulation_results::IARA.SimulationResultsFromPeriodScenario;
    period::Int,
    reference_curve_segment::Int,
    scenario::Int,
)
    quantity, price = post_process_reference_curve_outputs(
        inputs,
        run_time_options,
        simulation_results,
        period,
        scenario,
    )

    serialize_reference_curve(
        inputs,
        quantity,
        price;
        period,
        scenario,
    )

    write_reference_curve_output!(
        outputs,
        inputs,
        run_time_options,
        "hydro_reference_curve_quantity",
        quantity;
        period,
        reference_curve_segment,
        scenario,
        multiply_by = MW_to_GW(),
    )

    write_reference_curve_output!(
        outputs,
        inputs,
        run_time_options,
        "hydro_reference_curve_price",
        price;
        period,
        reference_curve_segment,
        scenario,
    )

    return nothing
end

function serialize_reference_curve(
    inputs::Inputs,
    quantity::Vector{Float64},
    price::Vector{Float64};
    period::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end
    serialized_file_name =
        joinpath(temp_path, "reference_curve_period_$(period)_scenario_$(scenario).json")

    if isfile(serialized_file_name)
        data_to_serialize = Serialization.deserialize(serialized_file_name)
    else
        data_to_serialize = Dict{Symbol, Any}()
        data_to_serialize[:quantity] = Vector{Float64}[]
        data_to_serialize[:price] = Vector{Float64}[]
    end
    push!(data_to_serialize[:quantity], round_output(quantity))
    push!(data_to_serialize[:price], round_output(price))

    Serialization.serialize(serialized_file_name, data_to_serialize)
    return nothing
end

function read_serialized_reference_curve(
    inputs::Inputs,
    period::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    serialized_file_name =
        joinpath(temp_path, "reference_curve_period_$(period)_scenario_$(scenario).json")

    if !isfile(serialized_file_name)
        return Vector{Float64}[], Vector{Float64}[]
    end

    data = Serialization.deserialize(serialized_file_name)
    return data[:quantity], data[:price]
end

function sum_previous_reference_curve_quantities(
    inputs::Inputs,
    reference_quantity::Vector{Vector{Float64}},
)
    number_of_virtual_reservoirs = number_of_elements(inputs, VirtualReservoir)
    reference_quantity_sum = zeros(number_of_virtual_reservoirs)
    for i in eachindex(reference_quantity)
        reference_quantity_sum .+= reference_quantity[i]
    end
    return reference_quantity_sum
end
