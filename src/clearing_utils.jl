#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function build_clearing_outputs(inputs::Inputs)
    run_time_options = RunTimeOptions()
    # TODO: this should be handled inside initialize_outputs()
    # but it probably requires another value in the RunTime_ClearingModelType enum
    heuristic_bids_outputs = Outputs()
    if generate_heuristic_bids_for_clearing(inputs)
        if any_elements(inputs, BiddingGroup)
            initialize_heuristic_bids_outputs(inputs, heuristic_bids_outputs, run_time_options)
        end
        if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS
            initialize_virtual_reservoir_bids_outputs(inputs, heuristic_bids_outputs, run_time_options)
        end
    end

    run_time_options = RunTimeOptions(; clearing_model_type = RunTime_ClearingModelType.EX_ANTE_PHYSICAL)
    ex_ante_physical_outputs = initialize_outputs(inputs, run_time_options)

    run_time_options = RunTimeOptions(; clearing_model_type = RunTime_ClearingModelType.EX_ANTE_COMMERCIAL)
    ex_ante_commercial_outputs = initialize_outputs(inputs, run_time_options)

    run_time_options = RunTimeOptions(; clearing_model_type = RunTime_ClearingModelType.EX_POST_PHYSICAL)
    ex_post_physical_outputs = initialize_outputs(inputs, run_time_options)

    run_time_options = RunTimeOptions(; clearing_model_type = RunTime_ClearingModelType.EX_POST_COMMERCIAL)
    ex_post_commercial_outputs = initialize_outputs(inputs, run_time_options)

    return heuristic_bids_outputs,
    ex_ante_physical_outputs,
    ex_ante_commercial_outputs,
    ex_post_physical_outputs,
    ex_post_commercial_outputs
end

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

function serialize_clearing_variables(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    simulation_results::SimulationResultsFromStageScenario;
    stage::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end
    serialized_file_name =
        joinpath(temp_path, "$(run_time_options.clearing_model_type)_stage_$(stage)_scenario_$(scenario).json")

    data_to_serialize = Dict{Symbol, Any}()
    for symbol in outputs.list_of_symbols_to_serialize
        data_to_serialize[symbol] = simulation_results.data[symbol]
    end

    Serialization.serialize(serialized_file_name, data_to_serialize)
    return nothing
end

function serialize_heuristic_bids(
    inputs::Inputs,
    quantity_offer::Array{Float64, 4},
    price_offer::Array{Float64, 4};
    stage::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end
    serialized_file_name =
        joinpath(temp_path, "heuristic_bids_stage_$(stage)_scenario_$(scenario).json")

    data_to_serialize = Dict{Symbol, Any}()
    data_to_serialize[:quantity_offer] = quantity_offer
    data_to_serialize[:price_offer] = price_offer

    Serialization.serialize(serialized_file_name, data_to_serialize)
    return nothing
end

function serialize_virtual_reservoir_heuristic_bids(
    inputs::Inputs,
    quantity_offer::Array{Float64, 3},
    price_offer::Array{Float64, 3};
    stage::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end
    serialized_file_name =
        joinpath(temp_path, "virtual_reservoir_heuristic_bids_stage_$(stage)_scenario_$(scenario).json")

    data_to_serialize = Dict{Symbol, Any}()
    data_to_serialize[:quantity_offer] = quantity_offer
    data_to_serialize[:price_offer] = price_offer

    Serialization.serialize(serialized_file_name, data_to_serialize)
    return nothing
end

function read_serialized_clearing_variable(
    inputs::Inputs,
    clearing_model_type::RunTime_ClearingModelType.T,
    symbol_to_read::Symbol;
    stage::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    serialized_file_name =
        joinpath(temp_path, "$(clearing_model_type)_stage_$(stage)_scenario_$(scenario).json")

    data = Serialization.deserialize(serialized_file_name)

    return data[symbol_to_read]
end

function read_serialized_heuristic_bids(
    inputs::Inputs;
    stage::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    serialized_file_name =
        joinpath(temp_path, "heuristic_bids_stage_$(stage)_scenario_$(scenario).json")

    data = Serialization.deserialize(serialized_file_name)

    return data[:quantity_offer], data[:price_offer]
end

function read_serialized_virtual_reservoir_heuristic_bids(
    inputs::Inputs;
    stage::Int,
    scenario::Int,
)
    temp_path = joinpath(path_case(inputs), "temp")
    serialized_file_name =
        joinpath(temp_path, "virtual_reservoir_heuristic_bids_stage_$(stage)_scenario_$(scenario).json")

    data = Serialization.deserialize(serialized_file_name)

    return data[:quantity_offer], data[:price_offer]
end

function is_ex_post_problem(run_time_options::RunTimeOptions)
    return run_time_options.clearing_model_type == RunTime_ClearingModelType.EX_POST_PHYSICAL ||
           run_time_options.clearing_model_type == RunTime_ClearingModelType.EX_POST_COMMERCIAL
end

function is_ex_ante_problem(run_time_options::RunTimeOptions)
    return run_time_options.clearing_model_type == RunTime_ClearingModelType.EX_ANTE_PHYSICAL ||
           run_time_options.clearing_model_type == RunTime_ClearingModelType.EX_ANTE_COMMERCIAL
end

function is_commercial_problem(run_time_options::RunTimeOptions)
    return run_time_options.clearing_model_type == RunTime_ClearingModelType.EX_ANTE_COMMERCIAL ||
           run_time_options.clearing_model_type == RunTime_ClearingModelType.EX_POST_COMMERCIAL
end

function is_physical_problem(run_time_options::RunTimeOptions)
    return run_time_options.clearing_model_type == RunTime_ClearingModelType.EX_ANTE_PHYSICAL ||
           run_time_options.clearing_model_type == RunTime_ClearingModelType.EX_POST_PHYSICAL
end

function clearing_has_fixed_binary_variables(inputs::Inputs, run_time_options::RunTimeOptions)
    if is_ex_ante_problem(run_time_options) && is_physical_problem(run_time_options)
        return false
    elseif is_ex_post_problem(run_time_options)
        return true
    elseif is_commercial_problem(run_time_options) && is_ex_ante_problem(run_time_options)
        return clearing_integer_variables(inputs) == Configurations_ClearingIntegerVariables.FIX
    else
        error("This function should not be called for non-clearing problems.")
    end
end

function clearing_has_linearized_binary_variables(inputs::Inputs, run_time_options::RunTimeOptions)
    if is_physical_problem(run_time_options) || is_ex_post_problem(run_time_options)
        return false
    elseif is_commercial_problem(run_time_options) && is_ex_ante_problem(run_time_options)
        return clearing_integer_variables(inputs) == Configurations_ClearingIntegerVariables.LINEARIZE
    else
        error("This function should not be called for non-clearing problems.")
    end
end

function clearing_has_volume_variables(inputs::Inputs, run_time_options::RunTimeOptions)
    if run_mode(inputs) != Configurations_RunMode.MARKET_CLEARING
        return false
    end
    if clearing_hydro_representation(inputs) == Configurations_ClearingHydroRepresentation.PURE_BIDS
        if is_ex_post_problem(run_time_options) && is_physical_problem(run_time_options)
            return true
        else
            return false
        end
    else
        return true
    end
end
