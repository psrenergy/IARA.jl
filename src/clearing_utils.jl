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

function serialize_heuristic_profile_bids(
    inputs::Inputs,
    quantity_profile_offers::Array{Float64, 4},
    price_profile_offers::Array{Float64, 2},
    complementary_grouping_profile::Array{Float64, 3},
    minimum_activation_level_profile::Array{Float64, 2},
    parent_profile::Array{Float64, 2};
    period::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end
    serialized_file_name =
        joinpath(temp_path, "heuristic_profile_bids_period_$(period)_scenario_$(scenario).json")

    data_to_serialize = Dict{Symbol, Any}()
    data_to_serialize[:quantity_profile_offers] = quantity_profile_offers
    data_to_serialize[:price_profile_offers] = price_profile_offers
    data_to_serialize[:complementary_grouping_profile] = complementary_grouping_profile
    data_to_serialize[:minimum_activation_level_profile] = minimum_activation_level_profile
    data_to_serialize[:parent_profile] = parent_profile

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

function read_serialized_heuristic_profile_bids(
    inputs::Inputs;
    period::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    serialized_file_name =
        joinpath(temp_path, "heuristic_profile_bids_period_$(period)_scenario_$(scenario).json")

    data = Serialization.deserialize(serialized_file_name)

    return data[:quantity_profile_offers], data[:price_profile_offers],
    data[:parent_profile], data[:complementary_grouping_profile],
    data[:minimum_activation_level_profile]
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

"""
    integer_variable_representation(inputs::Inputs, run_time_options::RunTimeOptions)

Determine the clearing integer variables.
"""
function integer_variable_representation(inputs::Inputs, run_time_options::RunTimeOptions)
    if is_ex_ante_problem(run_time_options)
        if is_physical_problem(run_time_options)
            return integer_variable_representation_ex_ante_physical_type(inputs)
        elseif is_commercial_problem(run_time_options)
            return integer_variable_representation_ex_ante_commercial_type(inputs)
        end
    elseif is_ex_post_problem(run_time_options)
        if is_physical_problem(run_time_options)
            return integer_variable_representation_ex_post_physical_type(inputs)
        elseif is_commercial_problem(run_time_options)
            return integer_variable_representation_ex_post_commercial_type(inputs)
        end
    end
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
    clearing_has_fixed_binary_variables_from_previous_problem(inputs::Inputs, run_time_options::RunTimeOptions)

Check if the clearing has fixed binary variables from the previous problem.
"""
function clearing_has_fixed_binary_variables_from_previous_problem(inputs::Inputs, run_time_options::RunTimeOptions)
    return integer_variable_representation(inputs, run_time_options) ==
           Configurations_IntegerVariableRepresentation.FROM_EX_ANTE_PHYSICAL
end

"""
    clearing_has_fixed_binary_variables(
        inputs::Inputs, 
        run_time_options::RunTimeOptions
    )

Check if the clearing has fixed binary variables.
"""
function clearing_has_fixed_binary_variables(inputs::Inputs, run_time_options::RunTimeOptions)
    return integer_variable_representation(inputs, run_time_options) ==
           Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY
end

"""
    clearing_has_linearized_binary_variables(inputs::Inputs, run_time_options::RunTimeOptions)

Check if the clearing has linearized binary variables.
"""
function clearing_has_linearized_binary_variables(inputs::Inputs, run_time_options::RunTimeOptions)
    return integer_variable_representation(inputs, run_time_options) ==
           Configurations_IntegerVariableRepresentation.LINEARIZE
end

"""
    clearing_has_volume_variables(inputs::Inputs, run_time_options::RunTimeOptions)

Check if the clearing has volume variables.
"""
function clearing_has_volume_variables(inputs::Inputs, run_time_options::RunTimeOptions)
    if !is_market_clearing(inputs)
        return false
    end
    return construction_type(inputs, run_time_options) != Configurations_ConstructionType.BID_BASED
end
