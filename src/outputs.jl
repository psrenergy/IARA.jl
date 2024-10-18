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

@kwdef mutable struct Outputs
    list_of_symbols_to_query_from_subproblem::Vector{Symbol} = Symbol[]
    list_of_symbols_to_serialize::Vector{Symbol} = Symbol[]
    list_of_custom_recorders_to_query_from_subproblem::Dict{Symbol, Function} = Dict{Symbol, Function}()
    outputs::Dict{String, AbstractOutput} = Dict{String, AbstractOutput}()
end

function output_path(inputs::Inputs)
    return joinpath(path_case(inputs), "outputs")
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

function initialize_outputs(inputs::Inputs, run_time_options::RunTimeOptions)
    outputs = Outputs()
    if run_mode(inputs) == Configurations_RunMode.HEURISTIC_BID
        initialize_heuristic_bids_outputs(inputs, outputs, run_time_options)
    else
        model_action(outputs, inputs, run_time_options, InitializeOutput)
    end
    return outputs
end

function initialize_output_dir(inputs)
    rm(output_path(inputs); force = true, recursive = true)
    mkdir(output_path(inputs))
    return nothing
end

mutable struct SimulationResults
    data::Vector{Vector{Dict{Symbol, Any}}}
end

mutable struct SimulationResultsFromStageScenario
    data::Dict{Symbol, Any}
end

function get_simulation_results_from_stage_scenario(simulation_results::SimulationResults, stage::Int, scenario::Int)
    return SimulationResultsFromStageScenario(simulation_results.data[scenario][stage])
end

function get_simulation_results_from_stage_scenario_subscenario(
    simulation_results::SimulationResults,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    stage::Int,
    scenario::Int,
    subscenario::Int,
)
    scenario_index = (scenario - 1) * number_of_subscenarios(inputs, run_time_options) + subscenario
    return SimulationResultsFromStageScenario(simulation_results.data[scenario_index][stage])
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
        if dimension == "stage"
            push!(dimension_size, number_of_stages(inputs))
        elseif dimension == "scenario"
            push!(dimension_size, number_of_scenarios(inputs))
        elseif dimension == "subscenario"
            push!(dimension_size, number_of_subscenarios(inputs, run_time_options))
        elseif dimension == "block"
            # TODO we should discuss if we should add a new condition to treat hydro blocks
            # The other option is to treat via the name of the output as we are doing here.
            if output_name in ["hydro_initial_volume"]
                hydro_blks = hydro_blocks(inputs)
                num_hydro_blocks = length(hydro_blks) - 1
                push!(dimension_size, num_hydro_blocks)
            else
                push!(dimension_size, number_of_blocks(inputs))
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
    frequency = stage_type_string(inputs.collections.configurations.stage_type)
    initial_date = inputs.collections.configurations.initial_date_time
    time_dimension = "stage"
    output_type = Quiver.csv

    dimensions = kwargs[:dimensions]
    if is_ex_post_problem(run_time_options)
        @assert dimensions[1] == "stage"
        @assert dimensions[2] == "scenario"
        dimensions = cat(dimensions[1:2], "subscenario", dimensions[3:end]; dims = 1)
    end
    unit = kwargs[:unit]
    labels = kwargs[:labels]

    output_name *= run_time_file_suffixes(run_time_options)

    file = joinpath(inputs.args.path, "outputs", output_name)
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
    # List of indices that will be written in a certain stage scenario iteration
    elements_to_write::Vector{Int},
)
    indices_of_elements_in_output = Vector{Int}(undef, length(elements_to_write))
    for (idx, element_to_write) in enumerate(elements_to_write)
        # When searchsorted does not find it will return a BoundsError. This is an error in the inputs.
        indices_of_elements_in_output[idx] = searchsorted(elements_in_output_file, element_to_write)[1]
    end
    return indices_of_elements_in_output
end

function write_output_per_block!(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    output_name::String,
    matrix_of_results::Matrix{T};
    stage::Int,
    scenario::Int,
    subscenario::Int,
    multiply_by::Float64 = 1.0,
    divide_by_block_duration_in_hours::Bool = false,
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
        if divide_by_block_duration_in_hours
            vector_to_write ./= block_duration_in_hours(inputs, blk)
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
                stage,
                scenario,
                subscenario,
                block = blk,
            )
        else
            Quiver.write!(
                output.writer,
                round_output(data);
                stage, scenario, block = blk,
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
    output_varies_per_block::Bool = true,
) where {T1 <: AbstractCollection, T2 <: AbstractCollection}
    number_of_pairs = sum(length(index_getter(inputs, idx)) for idx in 1:length(first_collection))
    blks = blocks(inputs)
    number_of_segments = maximum_number_of_virtual_reservoir_bidding_segments(inputs)

    treated_output = if output_varies_per_block
        zeros(number_of_blocks(inputs), number_of_pairs)
    else # assumes outout varies per segment (VR bids)
        zeros(number_of_pairs, number_of_segments)
    end

    number_of_pairs_fullfiled = 0
    for index1 in index_of_elements(inputs, T1; run_time_options), index2 in index_getter(inputs, index1)
        number_of_pairs_fullfiled += 1
        if output_varies_per_block
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
    stage::Int,
    scenario::Int,
    subscenario::Int,
    multiply_by::Float64 = 1.0,
    has_multihour_bids::Bool = false,
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
    if has_multihour_bids
        bid_profiles = bidding_profiles(inputs)
    else
        bid_segments = bidding_segments(inputs)
    end
    blks = blocks(inputs)
    bid_segments = bidding_segments(inputs)
    buses = index_of_elements(inputs, Bus)
    num_buses = length(buses)
    size_segments = has_multihour_bids ? length(bid_profiles) : length(bid_segments)
    # 4D array with dimensions: block, bidding_group, bid_segment, bus
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
        if has_multihour_bids
            for prf in bid_profiles
                for (i_bg, bg) in enumerate(bidding_groups_filtered), bus in buses
                    if prf > size_segments
                        continue
                    end
                    treated_output[blk, prf, (i_bg-1)*(num_buses)+bus] = data[blk, bg, prf, bus]
                end
                if is_ex_post_problem(run_time_options)
                    Quiver.write!(
                        output.writer,
                        round_output(treated_output[blk, prf, :] * multiply_by);
                        stage,
                        scenario,
                        subscenario,
                        block = blk,
                        profile = prf,
                    )
                else
                    Quiver.write!(
                        output.writer,
                        round_output(treated_output[blk, prf, :] * multiply_by);
                        stage,
                        scenario,
                        block = blk,
                        profile = prf,
                    )
                end
            end
        else
            for bds in bid_segments
                for (i_bg, bg) in enumerate(bidding_groups_filtered), bus in buses
                    # TODO: change back to maximum_bid_segments(inputs, bg) once it works 
                    # for HEURISTIC_BID cases
                    if bds > size_segments
                        continue
                    end
                    treated_output[blk, bds, (i_bg-1)*(num_buses)+bus] = data[blk, bg, bds, bus]
                end
                if is_ex_post_problem(run_time_options)
                    Quiver.write!(
                        output.writer,
                        round_output(treated_output[blk, bds, :] * multiply_by);
                        stage,
                        scenario,
                        subscenario,
                        block = blk,
                        bid_segment = bds,
                    )
                else
                    Quiver.write!(
                        output.writer,
                        round_output(treated_output[blk, bds, :] * multiply_by);
                        stage,
                        scenario,
                        block = blk,
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
    stage::Int,
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
                stage,
                scenario,
                subscenario,
                bid_segment = seg,
            )
        else
            Quiver.write!(
                output.writer,
                round_output(treated_output[seg, :] * multiply_by);
                stage,
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
