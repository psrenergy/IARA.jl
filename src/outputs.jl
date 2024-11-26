#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

abstract type AbstractOutput end

"""
    Outputs 

Struct to store parameters related to the outputs of the optimization problem.
"""
@kwdef mutable struct Outputs
    list_of_symbols_to_query_from_subproblem::Vector{Symbol} = Symbol[]
    list_of_symbols_to_serialize::Vector{Symbol} = Symbol[]
    list_of_custom_recorders_to_query_from_subproblem::Dict{Symbol, Function} = Dict{Symbol, Function}()
    outputs::Dict{String, AbstractOutput} = Dict{String, AbstractOutput}()
end

"""
    output_path(inputs::Inputs)

Return the path to the outputs directory.
"""
function output_path(inputs::Inputs)
    return output_path(inputs.args)
end

function output_path(args::Args)
    return args.outputs_path
end

function Base.getindex(outputs::Outputs, output::String)
    return outputs.outputs[output]
end

function add_symbol_to_query_from_subproblem_result!(outputs::Outputs, symbol_from_subproblem::Symbol)
    push!(outputs.list_of_symbols_to_query_from_subproblem, symbol_from_subproblem)
    return nothing
end

function add_symbol_to_query_from_subproblem_result!(outputs::Outputs, symbols_from_subproblem::Vector{Symbol})
    for symbol in symbols_from_subproblem
        add_symbol_to_query_from_subproblem_result!(outputs, symbol)
    end
    return nothing
end

function add_symbol_to_integer_variables_list!(run_time_options::RunTimeOptions, symbol_to_serialize::Symbol)
    if !(symbol_to_serialize in run_time_options.clearing_integer_variables_in_model)
        push!(run_time_options.clearing_integer_variables_in_model, symbol_to_serialize)
    end
    return nothing
end

function add_symbol_to_serialize!(outputs::Outputs, symbol_to_serialize::Symbol)
    push!(outputs.list_of_symbols_to_serialize, symbol_to_serialize)
    return nothing
end

function add_symbol_to_serialize!(outputs::Outputs, symbols_to_serialize::Vector{Symbol})
    for symbol in symbols_to_serialize
        add_symbol_to_serialize!(outputs, symbol)
    end
    return nothing
end

function add_custom_recorder_to_query_from_subproblem_result!(
    outputs::Outputs,
    symbol_from_subproblem::Symbol,
    custom_recorder::Function,
)
    outputs.list_of_custom_recorders_to_query_from_subproblem[symbol_from_subproblem] = custom_recorder
    return nothing
end

function add_custom_recorder_to_query_from_subproblem_result!(
    outputs::Outputs,
    symbols_from_subproblem::Vector{Symbol},
    custom_recorder::Function,
)
    for symbol in symbols_from_subproblem
        add_custom_recorder_to_query_from_subproblem_result!(outputs, symbol, custom_recorder)
    end
    return nothing
end

"""
    initialize_outputs(inputs::Inputs, run_time_options::RunTimeOptions)

Initialize the outputs struct.
"""
function initialize_outputs(inputs::Inputs, run_time_options::RunTimeOptions)
    outputs = Outputs()
    model_action(outputs, inputs, run_time_options, InitializeOutput)
    return outputs
end

function initialize_output_dir(args::Args)
    if !isdir(args.outputs_path)
        mkdir(args.outputs_path)
    end
    return nothing
end

mutable struct SimulationResults
    data::Vector{Vector{Dict{Symbol, Any}}}
end

mutable struct SimulationResultsFromPeriodScenario
    data::Dict{Symbol, Any}
end

function get_simulation_results_from_period_scenario(simulation_results::SimulationResults, period::Int, scenario::Int)
    return SimulationResultsFromPeriodScenario(simulation_results.data[scenario][period])
end

function get_simulation_results_from_period_scenario_subscenario(
    simulation_results::SimulationResults,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    period::Int,
    scenario::Int,
    subscenario::Int,
)
    scenario_index = (scenario - 1) * number_of_subscenarios(inputs, run_time_options) + subscenario
    return SimulationResultsFromPeriodScenario(simulation_results.data[scenario_index][period])
end

mutable struct QuiverOutput <: AbstractOutput
    writer::Quiver.Writer
end

function get_outputs_dimension_size(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    output_name::String,
    dimensions::Vector{String},
)
    dimension_size = Int[]
    for dimension in dimensions
        if dimension == "period"
            push!(dimension_size, number_of_periods(inputs))
        elseif dimension == "scenario"
            push!(dimension_size, number_of_scenarios(inputs))
        elseif dimension == "subscenario"
            push!(dimension_size, number_of_subscenarios(inputs, run_time_options))
        elseif dimension == "subperiod"
            # TODO we should discuss if we should add a new condition to treat hydro subperiods
            # The other option is to treat via the name of the output as we are doing here.
            if output_name in ["hydro_initial_volume"]
                hydro_blks = hydro_subperiods(inputs)
                num_hydro_subperiods = length(hydro_blks) - 1
                push!(dimension_size, num_hydro_subperiods)
            else
                push!(dimension_size, number_of_subperiods(inputs))
            end
        elseif dimension == "bid_segment"
            if occursin("virtual_reservoir", output_name)
                push!(dimension_size, maximum_number_of_virtual_reservoir_bidding_segments(inputs))
            else
                push!(dimension_size, maximum_number_of_bidding_segments(inputs))
            end
        elseif dimension == "profile"
            push!(dimension_size, maximum_number_of_bidding_profiles(inputs))
        else
            error("Dimension $dimension not recognized")
        end
    end
    return dimension_size
end

function initialize!(
    ::Type{QuiverOutput},
    outputs::Outputs;
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    output_name::String,
    kwargs...,
)
    frequency = period_type_string(inputs.collections.configurations.period_type)
    initial_date = inputs.collections.configurations.initial_date_time
    time_dimension = "period"
    output_type = Quiver.csv

    dimensions = kwargs[:dimensions]
    if is_ex_post_problem(run_time_options)
        @assert dimensions[1] == "period"
        @assert dimensions[2] == "scenario"
        dimensions = cat(dimensions[1:2], "subscenario", dimensions[3:end]; dims = 1)
    end
    unit = kwargs[:unit]
    labels = kwargs[:labels]

    output_name *= run_time_file_suffixes(run_time_options)

    file = joinpath(output_path(inputs), output_name)
    dimension_size = get_outputs_dimension_size(inputs, run_time_options, output_name, dimensions)

    writer = Quiver.Writer{output_type}(
        file;
        dimensions,
        labels,
        time_dimension,
        dimension_size,
        frequency,
        initial_date,
        unit,
    )

    output = QuiverOutput(writer)

    outputs.outputs[output_name] = output

    return nothing
end

function find_indices_of_elements_to_write_in_output(;
    # Complete list of indices from the collection that exist in 
    # the output file.
    elements_in_output_file::Vector{Int},
    # List of indices that will be written in a certain period scenario iteration
    elements_to_write::Vector{Int},
)
    indices_of_elements_in_output = Vector{Int}(undef, length(elements_to_write))
    for (idx, element_to_write) in enumerate(elements_to_write)
        # When searchsorted does not find it will return a BoundsError. This is an error in the inputs.
        indices_of_elements_in_output[idx] = searchsorted(elements_in_output_file, element_to_write)[1]
    end
    return indices_of_elements_in_output
end

function write_output_per_subperiod!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    output_name::String,
    matrix_of_results::Matrix{T};
    period::Int,
    scenario::Int,
    subscenario::Int,
    multiply_by::Float64 = 1.0,
    divide_by_subperiod_duration_in_hours::Bool = false,
    indices_of_elements_in_output::Union{Vector{Int}, Nothing} = nothing,
) where {T}

    # Pick the correct output based on the run time options
    output = outputs.outputs[output_name*run_time_file_suffixes(run_time_options)]

    # Create a vector of zeros based on the number of time series
    num_time_series = output.writer.metadata.number_of_time_series
    data = zeros(num_time_series)

    # Validate that the indices of the outputs match the jump_conatiner
    if indices_of_elements_in_output === nothing
        @assert size(matrix_of_results, 2) == num_time_series
    else
        @assert length(indices_of_elements_in_output) == size(matrix_of_results, 2)
    end

    # TODO review this, it is not iterating column wise
    for blk in axes(matrix_of_results, 1)
        vector_to_write = matrix_of_results[blk, :] * multiply_by
        if divide_by_subperiod_duration_in_hours
            vector_to_write ./= subperiod_duration_in_hours(inputs, blk)
        end
        if indices_of_elements_in_output === nothing
            # Write in all indices without filtering
            for (idx, value) in enumerate(vector_to_write)
                data[idx] = value
            end
        else
            # Write only the filtered indices that are in the output file
            for (idx, idx_in_output) in enumerate(indices_of_elements_in_output)
                data[idx_in_output] = vector_to_write[idx]
            end
        end
        if is_ex_post_problem(run_time_options)
            Quiver.write!(
                output.writer,
                round_output(data);
                period,
                scenario,
                subscenario,
                subperiod = blk,
            )
        else
            Quiver.write!(
                output.writer,
                round_output(data);
                period, scenario, subperiod = blk,
            )
        end
    end
    return nothing
end

function all_buses(inputs::Inputs, index1::Int)
    return 1:number_of_elements(inputs, Bus)
end

function labels_for_output_by_pair_of_agents(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    first_collection::T1,
    second_collection::T2;
    # index_getter is a function that receives the inputs and the index of the first collection
    # and returns the indices of the second collection that are associated with the elements 
    # of index1 in first collection.
    @nospecialize(index_getter::Function),
    # filters_to_apply_in_first_collection
    @nospecialize(filters_to_apply_in_first_collection::Vector{<:Function} = Function[]),
) where {T1 <: AbstractCollection, T2 <: AbstractCollection}
    labels = String[]
    index_of_elements_first_collection =
        index_of_elements(inputs, T1; run_time_options, filters = filters_to_apply_in_first_collection)
    for index1 in index_of_elements_first_collection
        for index2 in index_getter(inputs, index1)
            label_for_pair = first_collection.label[index1] * " - " * second_collection.label[index2]
            push!(labels, label_for_pair)
        end
    end
    return labels
end

function treat_output_for_writing_by_pairs_of_agents(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    raw_output,
    first_collection::T1,
    second_collection::T2;
    # index_getter is a function that receives the inputs and the index of the first collection
    # and returns the indices of the second collection that are associated with the elements 
    # of index1 in first collection.
    index_getter::Function,
    output_varies_per_subperiod::Bool = true,
) where {T1 <: AbstractCollection, T2 <: AbstractCollection}
    number_of_pairs = sum(length(index_getter(inputs, idx)) for idx in 1:length(first_collection))
    blks = subperiods(inputs)
    number_of_segments = maximum_number_of_virtual_reservoir_bidding_segments(inputs)

    treated_output = if output_varies_per_subperiod
        zeros(number_of_subperiods(inputs), number_of_pairs)
    else # assumes outout varies per segment (VR bids)
        zeros(number_of_pairs, number_of_segments)
    end

    number_of_pairs_fullfiled = 0
    for index1 in index_of_elements(inputs, T1; run_time_options), index2 in index_getter(inputs, index1)
        number_of_pairs_fullfiled += 1
        if output_varies_per_subperiod
            for blk in blks
                treated_output[blk, number_of_pairs_fullfiled] = raw_output[blk, index1, index2]
            end
        else # assumes outout varies per segment (VR bids)
            for segment in 1:number_of_segments
                treated_output[number_of_pairs_fullfiled, segment] = raw_output[index1, index2, segment]
            end
        end
    end

    @assert number_of_pairs_fullfiled == number_of_pairs

    return treated_output
end

function write_bid_output(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    output_name::String,
    data::Union{Array{Float64, 4}, OrderedDict{NTuple{4, Int64}, Float64}};
    period::Int,
    scenario::Int,
    subscenario::Int,
    multiply_by::Float64 = 1.0,
    has_profile_bids::Bool = false,
    @nospecialize(filters::Vector{<:Function} = Function[])
)
    # TODO: This function deserves a refactor
    all_bidding_groups = index_of_elements(inputs, BiddingGroup; run_time_options)
    bidding_groups_filtered = index_of_elements(
        inputs,
        BiddingGroup;
        run_time_options,
        filters = filters,
    )
    if has_profile_bids
        bid_profiles = bidding_profiles(inputs)
    else
        bid_segments = bidding_segments(inputs)
    end
    blks = subperiods(inputs)
    bid_segments = bidding_segments(inputs)
    buses = index_of_elements(inputs, Bus)
    num_buses = length(buses)
    size_segments = has_profile_bids ? length(bid_profiles) : length(bid_segments)
    # 4D array with dimensions: subperiod, bidding_group, bid_segment, bus
    if isa(data, Array{Float64, 4})
        @assert size(data, 1) == length(blks)
        @assert size(data, 2) == length(all_bidding_groups)
        @assert size(data, 3) == size_segments # TODO: maybe this configuration should be ignored for this mode.
        @assert size(data, 4) == length(buses)
    end

    # Pick the correct output based on the run time options
    output = outputs.outputs[output_name*run_time_file_suffixes(run_time_options)]

    treated_output = zeros(length(blks), size_segments, length(bidding_groups_filtered) * length(buses))

    for blk in blks
        if has_profile_bids
            for prf in bid_profiles
                for (i_bg, bg) in enumerate(bidding_groups_filtered), bus in buses
                    # TODO: change back to maximum_bid_profiles(inputs, bg)
                    if prf > size_segments
                        continue
                    end
                    treated_output[blk, prf, (i_bg-1)*(num_buses)+bus] = data[blk, bg, prf, bus]
                end
                if is_ex_post_problem(run_time_options)
                    Quiver.write!(
                        output.writer,
                        round_output(treated_output[blk, prf, :] * multiply_by);
                        period,
                        scenario,
                        subscenario,
                        subperiod = blk,
                        profile = prf,
                    )
                else
                    Quiver.write!(
                        output.writer,
                        round_output(treated_output[blk, prf, :] * multiply_by);
                        period,
                        scenario,
                        subperiod = blk,
                        profile = prf,
                    )
                end
            end
        else
            for bds in bid_segments
                for (i_bg, bg) in enumerate(bidding_groups_filtered), bus in buses
                    # TODO: change back to maximum_bid_segments(inputs, bg)
                    if bds > size_segments
                        continue
                    end
                    treated_output[blk, bds, (i_bg-1)*(num_buses)+bus] = data[blk, bg, bds, bus]
                end
                if is_ex_post_problem(run_time_options)
                    Quiver.write!(
                        output.writer,
                        round_output(treated_output[blk, bds, :] * multiply_by);
                        period,
                        scenario,
                        subscenario,
                        subperiod = blk,
                        bid_segment = bds,
                    )
                else
                    Quiver.write!(
                        output.writer,
                        round_output(treated_output[blk, bds, :] * multiply_by);
                        period,
                        scenario,
                        subperiod = blk,
                        bid_segment = bds,
                    )
                end
            end
        end
    end
end

function write_virtual_reservoir_bid_output(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    output_name::String,
    data::Array{Float64, 3}, #Union{Array{Float64, 3}, OrderedDict{NTuple{3, Int64}, Float64}};
    period::Int,
    scenario::Int;
    subscenario::Int = 1,
    multiply_by::Float64 = 1.0,
    # @nospecialize(filters::Vector{<:Function} = Function[])
)
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir; run_time_options) # why run_time_options?
    asset_owners = index_of_elements(inputs, AssetOwner; run_time_options)

    # 3D array with dimensions: virtual_reservoir, asset_owner, bid_segment
    @assert size(data, 1) == length(virtual_reservoirs)
    @assert size(data, 2) == length(asset_owners)
    number_of_segments = size(data, 3)

    # Pick the correct output based on the run time options
    output = outputs.outputs[output_name*run_time_file_suffixes(run_time_options)]

    number_of_asset_owners_per_virtual_reservoir = length.(virtual_reservoir_asset_owner_indices(inputs))
    treated_output = zeros(number_of_segments, sum(number_of_asset_owners_per_virtual_reservoir))

    for seg in 1:number_of_segments
        pair_index = 0
        for vr in virtual_reservoirs
            for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
                pair_index += 1
                treated_output[seg, pair_index] = data[vr, ao, seg]
            end
        end
        if is_ex_post_problem(run_time_options)
            Quiver.write!(
                output.writer,
                round_output(treated_output[seg, :] * multiply_by);
                period,
                scenario,
                subscenario,
                bid_segment = seg,
            )
        else
            Quiver.write!(
                output.writer,
                round_output(treated_output[seg, :] * multiply_by);
                period,
                scenario,
                bid_segment = seg,
            )
        end
    end
end

function run_time_file_suffixes(run_time_options::RunTimeOptions)
    suffix = ""
    if !is_null(run_time_options.asset_owner_index)
        suffix *= "_asset_owner_$(run_time_options.asset_owner_index)"
    end
    if run_time_options.clearing_model_procedure !== nothing
        suffix *= "_$(lowercase(string(run_time_options.clearing_model_procedure)))"
    end

    return suffix
end

function round_output(v::Vector{T}) where {T}
    return round.(v, digits = 6)
end

function finalize!(output::QuiverOutput)
    return Quiver.close!(output.writer)
end

function finalize_outputs!(outputs::Outputs)
    for output in values(outputs.outputs)
        finalize!(output)
    end
    return nothing
end
