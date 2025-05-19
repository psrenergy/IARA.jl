#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################
"""
    build_clearing_outputs(inputs::Inputs)

Build the outputs for the clearing subproblem.
"""
function build_clearing_outputs(inputs::Inputs)
    run_time_options = RunTimeOptions()
    # TODO: this should be handled inside initialize_outputs()
    # but it probably requires another value in the RunTime_ClearingSubproblem enum
    heuristic_bids_outputs = Outputs()
    if generate_heuristic_bids_for_clearing(inputs)
        if any_elements(inputs, BiddingGroup)
            initialize_heuristic_bids_outputs(inputs, heuristic_bids_outputs, run_time_options)
        end
        if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            initialize_virtual_reservoir_bids_outputs(inputs, heuristic_bids_outputs, run_time_options)
        end
    end

    run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL)
    ex_ante_physical_outputs = initialize_outputs(inputs, run_time_options)

    run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_ANTE_COMMERCIAL)
    ex_ante_commercial_outputs = initialize_outputs(inputs, run_time_options)

    run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_PHYSICAL)
    ex_post_physical_outputs = initialize_outputs(inputs, run_time_options)

    run_time_options = RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_COMMERCIAL)
    ex_post_commercial_outputs = initialize_outputs(inputs, run_time_options)

    return heuristic_bids_outputs,
    ex_ante_physical_outputs,
    ex_ante_commercial_outputs,
    ex_post_physical_outputs,
    ex_post_commercial_outputs
end

"""
    finalize_clearing_outputs!(heuristic_bids_outputs::Outputs, ex_ante_physical_outputs::Outputs, ex_ante_commercial_outputs::Outputs, ex_post_physical_outputs::Outputs, ex_post_commercial_outputs::Outputs)

Finalize the outputs for the clearing subproblem.
"""
function finalize_clearing_outputs!(
    heuristic_bids_outputs::Outputs,
    ex_ante_physical_outputs::Outputs,
    ex_ante_commercial_outputs::Outputs,
    ex_post_physical_outputs::Outputs,
    ex_post_commercial_outputs::Outputs,
)
    finalize_outputs!(heuristic_bids_outputs)
    finalize_outputs!(ex_ante_physical_outputs)
    finalize_outputs!(ex_ante_commercial_outputs)
    finalize_outputs!(ex_post_physical_outputs)
    finalize_outputs!(ex_post_commercial_outputs)

    return nothing
end

"""
    fix_discrete_variables_from_previous_problem!(inputs::Inputs, run_time_options::RunTimeOptions, model::JuMP.Model, period::Int, scen::Int)

Fix discrete variables from the previous problem.
"""
function fix_discrete_variables_from_previous_problem!(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    model::JuMP.Model,
    period::Int,
    scen::Int,
)
    relax_integrality(model)
    for symbol in run_time_options.clearing_integer_variables_in_model
        previous_problem_integer_values = read_serialized_clearing_variable(
            inputs,
            RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL,
            symbol;
            period = period,
            scenario = scen,
        )
        fix.(
            model[symbol],
            previous_problem_integer_values;
            force = true,
        )
    end

    return nothing
end

"""
    serialize_clearing_variables(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, simulation_results::SimulationResultsFromPeriodScenario; period::Int, scenario::Int)

Serialize clearing variables.
"""
function serialize_clearing_variables(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromPeriodScenario;
    period::Int,
    scenario::Int,
)
    temp_path = if run_mode(inputs) == RunMode.SINGLE_PERIOD_MARKET_CLEARING
        output_path(inputs)
    else
        temp_path = joinpath(path_case(inputs), "temp")
        if !isdir(temp_path)
            mkdir(temp_path)
        end
        temp_path
    end
    serialized_file_name =
        joinpath(temp_path, "$(run_time_options.clearing_model_subproblem)_period_$(period)_scenario_$(scenario).json")

    data_to_serialize = Dict{Symbol, Any}()
    for symbol in outputs.list_of_symbols_to_serialize
        data_to_serialize[symbol] = simulation_results.data[symbol]
    end

    Serialization.serialize(serialized_file_name, data_to_serialize)
    return nothing
end

"""
    serialize_heuristic_bids(inputs::Inputs, quantity_offer::Array{Float64, 4}, price_offer::Array{Float64, 4}; period::Int, scenario::Int)

Serialize heuristic bids.
"""
function serialize_heuristic_bids(
    inputs::Inputs,
    quantity_offer::Array{Float64, 4},
    price_offer::Array{Float64, 4};
    period::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end
    serialized_file_name =
        joinpath(temp_path, "heuristic_bids_period_$(period)_scenario_$(scenario).json")

    data_to_serialize = Dict{Symbol, Any}()
    data_to_serialize[:quantity_offer] = quantity_offer
    data_to_serialize[:price_offer] = price_offer

    Serialization.serialize(serialized_file_name, data_to_serialize)
    return nothing
end

"""
    serialize_virtual_reservoir_heuristic_bids(inputs::Inputs, quantity_offer::Array{Float64, 3}, price_offer::Array{Float64, 3}; period::Int, scenario::Int)   

Serialize virtual reservoir heuristic bids.
"""
function serialize_virtual_reservoir_heuristic_bids(
    inputs::Inputs,
    quantity_offer::Array{Float64, 3},
    price_offer::Array{Float64, 3};
    period::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end
    serialized_file_name =
        joinpath(temp_path, "virtual_reservoir_heuristic_bids_period_$(period)_scenario_$(scenario).json")

    data_to_serialize = Dict{Symbol, Any}()
    data_to_serialize[:quantity_offer] = quantity_offer
    data_to_serialize[:price_offer] = price_offer

    Serialization.serialize(serialized_file_name, data_to_serialize)
    return nothing
end

"""
    read_serialized_clearing_variable(inputs::Inputs, clearing_model_subproblem::RunTime_ClearingSubproblem.T, symbol_to_read::Symbol; period::Int, scenario::Int)

Read serialized clearing variable.
"""
function read_serialized_clearing_variable(
    inputs::Inputs,
    clearing_model_subproblem::RunTime_ClearingSubproblem.T,
    symbol_to_read::Symbol;
    period::Int,
    scenario::Int,
)
    temp_path = if run_mode(inputs) == RunMode.SINGLE_PERIOD_MARKET_CLEARING
        path_case(inputs)
    else
        joinpath(path_case(inputs), "temp")
    end
    serialized_file_name =
        joinpath(temp_path, "$(clearing_model_subproblem)_period_$(period)_scenario_$(scenario).json")

    if !isfile(serialized_file_name)
        error_message = "File $serialized_file_name not found."
        if run_mode(inputs) == RunMode.SINGLE_PERIOD_MARKET_CLEARING
            error_message *= " In single period market clearing, make sure the previous period has been solved, and the .json files have been copied from the previous execution's output directory."
        end
        error(error_message)
    end

    data = Serialization.deserialize(serialized_file_name)

    return data[symbol_to_read]
end

"""
    read_serialized_heuristic_bids(inputs::Inputs; period::Int, scenario::Int)

Read serialized heuristic bids.
"""
function read_serialized_heuristic_bids(
    inputs::Inputs;
    period::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    serialized_file_name =
        joinpath(temp_path, "heuristic_bids_period_$(period)_scenario_$(scenario).json")
    data = Serialization.deserialize(serialized_file_name)

    return data[:quantity_offer], data[:price_offer]
end

"""
    read_serialized_virtual_reservoir_heuristic_bids(inputs::Inputs; period::Int, scenario::Int)

Read serialized virtual reservoir heuristic bids.
"""
function read_serialized_virtual_reservoir_heuristic_bids(
    inputs::Inputs;
    period::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    serialized_file_name =
        joinpath(temp_path, "virtual_reservoir_heuristic_bids_period_$(period)_scenario_$(scenario).json")

    data = Serialization.deserialize(serialized_file_name)

    return data[:quantity_offer], data[:price_offer]
end

"""
    construction_type(inputs::Inputs, run_time_options::RunTimeOptions)

Determine the clearing model type.
"""
function construction_type(inputs::Inputs, run_time_options::RunTimeOptions)
    if is_ex_ante_problem(run_time_options)
        if is_physical_problem(run_time_options)
            return construction_type_ex_ante_physical(inputs)
        elseif is_commercial_problem(run_time_options)
            return construction_type_ex_ante_commercial(inputs)
        end
    elseif is_ex_post_problem(run_time_options)
        if is_physical_problem(run_time_options)
            return construction_type_ex_post_physical(inputs)
        elseif is_commercial_problem(run_time_options)
            return construction_type_ex_post_commercial(inputs)
        end
    end
end

"""
    skip_clearing_subproblem(inputs::Inputs, run_time_options::RunTimeOptions)

Check if the clearing subproblem should be skipped.
"""
function skip_clearing_subproblem(inputs::Inputs, run_time_options::RunTimeOptions)
    return construction_type(inputs, run_time_options) == Configurations_ConstructionType.SKIP
end

function is_mincost(inputs::Inputs)
    return run_mode(inputs) == RunMode.TRAIN_MIN_COST || run_mode(inputs) == RunMode.MIN_COST
end

"""
    is_ex_post_problem(run_time_options::RunTimeOptions)

Check if the problem is ex-post.
"""
function is_ex_post_problem(run_time_options::RunTimeOptions)
    return run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_POST_PHYSICAL ||
           run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_POST_COMMERCIAL
end

"""
    is_ex_ante_problem(run_time_options::RunTimeOptions)

Check if the problem is ex-ante.
"""
function is_ex_ante_problem(run_time_options::RunTimeOptions)
    return run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL ||
           run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_ANTE_COMMERCIAL
end

"""
    is_commercial_problem(run_time_options::RunTimeOptions)

Check if the problem is commercial.
"""
function is_commercial_problem(run_time_options::RunTimeOptions)
    return run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_ANTE_COMMERCIAL ||
           run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_POST_COMMERCIAL
end

"""
    is_physical_problem(run_time_options::RunTimeOptions)

Check if the problem is physical.
"""
function is_physical_problem(run_time_options::RunTimeOptions)
    return run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_ANTE_PHYSICAL ||
           run_time_options.clearing_model_subproblem == RunTime_ClearingSubproblem.EX_POST_PHYSICAL
end

"""
    clearing_has_state_variables(inputs::Inputs, run_time_options::RunTimeOptions)

Check if the clearing has any representation that requires state variables.
"""
function clearing_has_state_variables(inputs::Inputs, run_time_options::RunTimeOptions)
    n_volume_states = number_of_elements(inputs, HydroUnit; filters = [operates_with_reservoir])
    if n_volume_states > 0
        return true
    end
    n_battery_states = number_of_elements(inputs, BatteryUnit)
    if n_battery_states > 0
        return true
    end
    return false
end

"""
    read_cuts_into_clearing_model!(
        model::ProblemModel, 
        inputs::Inputs, 
        run_time_options::RunTimeOptions, 
        period::Int
    )

Check if the clearing representation must read cuts. If so, it reads them.
"""
function read_cuts_into_clearing_model!(
    model::ProblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
)
    # We could choose to add cuts to the model as a user
    if use_fcf_in_clearing(inputs)
        read_cuts_to_model!(model, inputs, run_time_options; current_period = period)
    elseif clearing_representation_must_read_cuts(inputs, run_time_options)
        if !has_fcf_cuts_to_read(inputs)
            error("Construction type is COST_BASED, the problem has state variables and no cuts file was provided.")
        end
        read_cuts_to_model!(model, inputs, run_time_options; current_period = period)
    end
    return nothing
end

"""
    clearing_representation_must_read_cuts(
        inputs::Inputs, 
        run_time_options::RunTimeOptions
    )

Check if the clearing representation must read cuts.
"""
function clearing_representation_must_read_cuts(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    if construction_type(inputs, run_time_options) == Configurations_ConstructionType.COST_BASED &&
       clearing_has_state_variables(inputs, run_time_options)
        return true
    end
    return false
end

"""
    clearing_has_volume_variables(inputs::Inputs, run_time_options::RunTimeOptions)

Check if the clearing has volume variables.
"""
function clearing_has_volume_variables(inputs::Inputs, run_time_options::RunTimeOptions)
    if !is_market_clearing(inputs)
        return false
    end
    if number_of_elements(inputs, HydroUnit) == 0
        return false
    end
    return construction_type(inputs, run_time_options) != Configurations_ConstructionType.BID_BASED
end

"""
    clearing_has_physical_variables(inputs::Inputs)

Check if the market clearing has physical variables in at least one of its problems.
"""
function clearing_has_physical_variables(inputs::Inputs)
    physical_variable_model_types = [
        Configurations_ConstructionType.COST_BASED,
        Configurations_ConstructionType.HYBRID,
    ]
    if construction_type_ex_ante_physical(inputs) in physical_variable_model_types ||
       construction_type_ex_ante_commercial(inputs) in physical_variable_model_types ||
       construction_type_ex_post_physical(inputs) in physical_variable_model_types ||
       construction_type_ex_post_commercial(inputs) in physical_variable_model_types
        return true
    else
        return false
    end
end

function serialize_virtual_reservoir_energy_account(
    inputs::Inputs,
    energy_account::Vector{Vector{Float64}},
    period::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end
    serialized_file_name =
        joinpath(temp_path, "virtual_reservoir_energy_account_period_$(period)_scenario_$(scenario).json")

    data_to_serialize = energy_account

    Serialization.serialize(serialized_file_name, data_to_serialize)
    return nothing
end

function read_serialized_virtual_reservoir_energy_account(inputs::Inputs, period::Int, scenario::Int)
    temp_path = if run_mode(inputs) == RunMode.SINGLE_PERIOD_MARKET_CLEARING
        path_case(inputs)
    else
        joinpath(path_case(inputs), "temp")
    end
    serialized_file_name =
        joinpath(temp_path, "virtual_reservoir_energy_account_period_$(period)_scenario_$(scenario).json")

    if !isfile(serialized_file_name)
        error_message = "File $serialized_file_name not found."
        if run_mode(inputs) == RunMode.SINGLE_PERIOD_MARKET_CLEARING
            error_message *= " In single period market clearing, make sure the previous period has been solved, and the .json files have been copied from the previous execution's output directory."
        end
        error(error_message)
    end

    data = Serialization.deserialize(serialized_file_name)

    return data
end

"""
    scale_cuts(input_file::String, output_file::String, factor::Float64)

Read FCF cuts from input_file, multiply all intercepts and coefficients by factor (preserving states),
and save the result to output_file.
"""
function scale_cuts(input_file::String, output_file::String, factor::Float64)
    # Read the JSON file
    data = open(input_file, "r") do f
        return SDDP.JSON.parse(f)
    end

    # Make a deep copy to avoid modifying the original data
    scaled_data = deepcopy(data)

    # Iterate through all nodes
    for node_data in scaled_data
        # Scale single cuts
        for cut in get(node_data, "single_cuts", [])
            cut["intercept"] *= factor
            for (var, coef) in cut["coefficients"]
                cut["coefficients"][var] = coef * factor
            end
        end

        # Scale multi cuts if they exist
        for cut in get(node_data, "multi_cuts", [])
            cut["intercept"] *= factor
            for (var, coef) in cut["coefficients"]
                cut["coefficients"][var] = coef * factor
            end
        end

        # Scale risk set cuts if they exist
        for cut in get(node_data, "risk_set_cuts", [])
            cut["intercept"] *= factor
            for (var, coef) in cut["coefficients"]
                cut["coefficients"][var] = coef * factor
            end
        end
    end

    # Write the scaled data to the output file
    open(output_file, "w") do f
        return SDDP.JSON.print(f, scaled_data)
    end

    return scaled_data
end
