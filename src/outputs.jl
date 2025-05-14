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

@kwdef mutable struct OutputReaders
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
        mkpath(args.outputs_path)
    else
        if args.delete_output_folder_before_execution
            if length(readdir(args.outputs_path)) > 0
                @warn(
                    "The output directory $(args.outputs_path) is not empty, and the argument " *
                    "`delete_output_folder_before_execution` has been provided. " *
                    "The directory's contents will be deleted."
                )
                rm(args.outputs_path; force = true, recursive = true)
                mkdir(args.outputs_path)
            end
        else
            if length(readdir(args.outputs_path)) > 0
                error(
                    "The output directory $(args.outputs_path) is not empty. " *
                    "Please choose another path or run IARA with the argument `delete_output_folder_before_execution`. " *
                    "You can change the output path with the argument output_path. " *
                    "For example, IARA.market_clearing(PATH; output_path = \"path/to/output\")",
                )
            end
        end
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

mutable struct QuiverInput <: AbstractOutput
    reader::Quiver.Reader
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
            if is_single_period(inputs)
                push!(dimension_size, 1)
            else
                push!(dimension_size, number_of_periods(inputs))
            end
        elseif dimension == "scenario"
            push!(dimension_size, number_of_scenarios(inputs))
        elseif dimension == "subscenario"
            push!(dimension_size, number_of_subscenarios(inputs, run_time_options))
        elseif dimension == "subperiod"
            if output_name in ["hydro_initial_volume", "hydro_final_volume"]
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
        elseif dimension == "complementary_group"
            push!(dimension_size, maximum_number_of_complementary_grouping(inputs))
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
    dir_path::String = output_path(inputs),
    kwargs...,
)
    frequency = period_type_string(inputs.collections.configurations.time_series_step)
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

    output_name *= run_time_file_suffixes(inputs, run_time_options)

    file = joinpath(dir_path, output_name)
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

post_processing_path(inputs) = joinpath(output_path(inputs), "post_processing")

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

    # Quiver file dimensions are always 1:N, so we need to set the period to 1
    if is_single_period(inputs)
        period = 1
    end

    # Pick the correct output based on the run time options
    output = outputs.outputs[output_name*run_time_file_suffixes(inputs, run_time_options)]

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
    valid_segments = get_maximum_valid_virtual_reservoir_segments(inputs)
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
            for segment in 1:valid_segments[index1]
                treated_output[number_of_pairs_fullfiled, segment] = raw_output[index1, index2, segment]
            end
        end
    end

    @assert number_of_pairs_fullfiled == number_of_pairs

    return treated_output
end

"""
    write_bid_output(
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

Write bid output data to the specified output file.

# Arguments
- `outputs`: The outputs struct containing the output writers
- `inputs`: The inputs struct containing model data
- `run_time_options`: Runtime options for the model
- `output_name`: Base name of the output file
- `data`: 4D array or OrderedDict containing the bid data
- `period`: Current period
- `scenario`: Current scenario
- `subscenario`: Current subscenario
- `multiply_by`: Scaling factor for the output data
- `has_profile_bids`: Whether the bids are profile-based
- `filters`: Filters to apply to the bidding groups
"""
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
    # Adjust period for single period case
    period = is_single_period(inputs) ? 1 : period

    # Get bidding groups and filter them
    all_bidding_groups = index_of_elements(
        inputs,
        BiddingGroup;
        run_time_options,
        filters = [has_generation_besides_virtual_reservoirs],
    )

    bidding_groups_filtered = index_of_elements(
        inputs,
        BiddingGroup;
        run_time_options,
        filters = filters,
    )

    # Initialize bid segments or profiles based on bid type
    if has_profile_bids
        bid_items = bidding_profiles(inputs)
        valid_items = get_maximum_valid_profiles(inputs)
        item_name = :profile
    else
        bid_items = bidding_segments(inputs)
        valid_items = get_maximum_valid_segments(inputs)
        item_name = :bid_segment
    end

    # Get common data structures
    blks = subperiods(inputs)
    buses = index_of_elements(inputs, Bus)
    num_buses = length(buses)
    num_items = length(bid_items)

    # Validate data dimensions if it's a 4D array
    if isa(data, Array{Float64, 4})
        validate_data_dimensions(data, length(blks), length(all_bidding_groups), num_items, length(buses))
    end

    # Get the output writer
    output = get_output_writer(outputs, inputs, run_time_options, output_name)

    # Process and write the data
    treated_output = zeros(length(blks), num_items, length(bidding_groups_filtered) * num_buses)

    for blk in blks
        for (item_idx, item) in enumerate(bid_items)
            process_bids_for_item!(
                treated_output, data, blk, item_idx, item, valid_items,
                bidding_groups_filtered, buses, has_profile_bids, num_buses,
            )

            # Write the processed data
            write_bid_data(
                output.writer,
                view(treated_output, blk, item_idx, :),
                period,
                scenario,
                subscenario,
                item,
                run_time_options,
                multiply_by;
                subperiod = blk,
                (has_profile_bids ? :profile : :bid_segment) => item,
            )
        end
    end
end

"""
    validate_data_dimensions(data::Array{Float64, 4}, n_blks::Int, n_bgs::Int, n_items::Int, n_buses::Int)

Validate that the dimensions of the input data array match the expected dimensions.
"""
function validate_data_dimensions(data::Array{Float64, 4}, n_blks::Int, n_bgs::Int, n_items::Int, n_buses::Int)
    dims = size(data)
    @assert dims[1] == n_blks "First dimension (subperiods) mismatch: expected $n_blks, got $(dims[1])"
    @assert dims[2] == n_bgs "Second dimension (bidding groups) mismatch: expected $n_bgs, got $(dims[2])"
    @assert dims[3] == n_items "Third dimension (bid items) mismatch: expected $n_items, got $(dims[3])"
    @assert dims[4] == n_buses "Fourth dimension (buses) mismatch: expected $n_buses, got $(dims[4])"
end

"""
    get_output_writer(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, output_name::String)

Get the appropriate output writer based on the output name and runtime options.
"""
function get_output_writer(outputs::Outputs, inputs::Inputs, run_time_options::RunTimeOptions, output_name::String)
    full_output_name = output_name * run_time_file_suffixes(inputs, run_time_options)
    return outputs.outputs[full_output_name]
end

"""
    process_bids_for_item!(
        treated_output::Array{Float64, 3},
        data::Union{Array{Float64, 4}, OrderedDict{NTuple{4, Int64}, Float64}},
        blk::Int,
        item_idx::Int,
        item::Int,
        valid_items::AbstractVector{Int},
        bidding_groups_filtered::Vector{Int},
        buses::Vector{Int},
        has_profile_bids::Bool,
        num_buses::Int
    )

Process bids for a specific item (segment or profile) and update the treated output array.
"""
function process_bids_for_item!(
    treated_output::Array{Float64, 3},
    data::Union{Array{Float64, 4}, OrderedDict{NTuple{4, Int64}, Float64}},
    blk::Int,
    item_idx::Int,
    item::Int,
    valid_items::AbstractVector{Int},
    bidding_groups_filtered::Vector{Int},
    buses::Vector{Int},
    has_profile_bids::Bool,
    num_buses::Int,
)
    for (i_bg, bg) in enumerate(bidding_groups_filtered), (bus_idx, bus) in enumerate(buses)
        # Skip if the current item is not valid for this bidding group
        item > valid_items[bg] && continue

        # Get the data point, handling both array and OrderedDict inputs
        data_point = if isa(data, Array{Float64, 4})
            data[blk, i_bg, item, bus]
        else
            data[blk, bg, item, bus]
        end

        # Calculate the index in the flattened output array
        output_idx = (i_bg - 1) * num_buses + bus_idx
        treated_output[blk, item_idx, output_idx] = data_point
    end
end

"""
    write_bid_data(
        writer,
        data::AbstractVector{Float64},
        period::Int,
        scenario::Int,
        subscenario::Int,
        item::Int,
        run_time_options::RunTimeOptions,
        multiply_by::Float64;
        subperiod::Union{Int, Nothing} = nothing,
        bid_segment::Union{Int, Nothing} = nothing,
        profile::Union{Int, Nothing} = nothing
    )

Write the processed bid data to the output file. This function handles both regular bids and virtual reservoir bids.

# Arguments
- `writer`: The Quiver writer object
- `data`: Vector of data points to write
- `period`: Current period
- `scenario`: Current scenario
- `subscenario`: Current subscenario
- `item`: The item number (segment or profile)
- `run_time_options`: Runtime options for the model
- `multiply_by`: Scaling factor for the output data
- `subperiod`: The subperiod (for regular bids, optional)
- `bid_segment`: The bid segment (for virtual reservoir bids, optional)
- `profile`: The profile (for profile bids, optional)

# Notes
- If `subperiod` is provided, it's a regular bid`
- Otherwise, it's a virtual reservoir bid
"""
function write_bid_data(
    writer,
    data::AbstractVector{Float64},
    period::Int,
    scenario::Int,
    subscenario::Int,
    item::Int,
    run_time_options::RunTimeOptions,
    multiply_by::Float64;
    subperiod::Union{Int, Nothing} = nothing,
    bid_segment::Union{Int, Nothing} = nothing,
    profile::Union{Int, Nothing} = nothing,
)
    # If subperiod is provided, it's a regular bid
    if subperiod !== nothing
        kwargs = (
            period = period,
            scenario = scenario,
            subperiod = subperiod,
            (profile !== nothing ? :profile : :bid_segment) => item,
        )
    else
        # If subperiod is not provided, it's a virtual reservoir bid
        kwargs = (
            period = period,
            scenario = scenario,
            bid_segment = item,
        )
    end

    # Add subscenario if this is an ex-post problem
    if is_ex_post_problem(run_time_options)
        kwargs = (kwargs..., subscenario = subscenario)
    end

    # Write the data
    return Quiver.write!(writer, round_output(data .* multiply_by); kwargs...)
end

"""
    write_virtual_reservoir_bid_output(
        outputs::Outputs,
        inputs::Inputs,
        run_time_options::RunTimeOptions,
        output_name::String,
        data::Array{Float64, 3};
        period::Int,
        scenario::Int;
        subscenario::Int = 1,
        multiply_by::Float64 = 1.0
    )

Write virtual reservoir bid output data to the specified output file.

# Arguments
- `outputs`: The outputs struct containing the output writers
- `inputs`: The inputs struct containing model data
- `run_time_options`: Runtime options for the model
- `output_name`: Base name of the output file
- `data`: 3D array containing the virtual reservoir bid data with dimensions [virtual_reservoir, asset_owner, bid_segment]
- `period`: Current period
- `scenario`: Current scenario
- `subscenario`: Current subscenario (default: 1)
- `multiply_by`: Scaling factor for the output data (default: 1.0)
"""
function write_virtual_reservoir_bid_output(
    outputs::Outputs,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    output_name::String,
    data::Array{Float64, 3};
    period::Int,
    scenario::Int,
    subscenario::Int = 1,
    multiply_by::Float64 = 1.0,
)
    # Adjust period for single period case
    period = is_single_period(inputs) ? 1 : period

    # Get virtual reservoirs and asset owners
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir; run_time_options)
    asset_owners = index_of_elements(inputs, AssetOwner; run_time_options)
    number_of_segments = size(data, 3)

    # Validate input data dimensions
    validate_vr_data_dimensions(data, length(virtual_reservoirs), length(asset_owners))

    # Get the output writer and prepare the output array
    output = get_output_writer(outputs, inputs, run_time_options, output_name)
    treated_output = prepare_vr_output_array(inputs, virtual_reservoirs, number_of_segments)

    # Process and write data for each segment
    for seg in 1:number_of_segments
        process_vr_bids_for_segment!(
            treated_output, data, seg, virtual_reservoirs, inputs,
        )

        # Write the processed data
        write_bid_data(
            output.writer,
            view(treated_output, seg, :),
            period,
            scenario,
            subscenario,
            seg,
            run_time_options,
            multiply_by;
            bid_segment = seg,
        )
    end
end

"""
    validate_vr_data_dimensions(data::Array{Float64, 3}, n_vrs::Int, n_aos::Int)

Validate that the dimensions of the input virtual reservoir data array match the expected dimensions.
"""
function validate_vr_data_dimensions(data::Array{Float64, 3}, n_vrs::Int, n_aos::Int)
    dims = size(data)
    @assert dims[1] == n_vrs "First dimension (virtual reservoirs) mismatch: expected $n_vrs, got $(dims[1])"
    @assert dims[2] == n_aos "Second dimension (asset owners) mismatch: expected $n_aos, got $(dims[2])"
end

"""
    prepare_vr_output_array(inputs::Inputs, virtual_reservoirs::Vector{Int}, n_segments::Int)

Prepare the output array for virtual reservoir bid data.
"""
function prepare_vr_output_array(inputs::Inputs, virtual_reservoirs::Vector{Int}, n_segments::Int)
    number_of_asset_owners_per_vr = length.(virtual_reservoir_asset_owner_indices(inputs))
    total_pairs = sum(number_of_asset_owners_per_vr)
    return zeros(n_segments, total_pairs)
end

"""
    process_vr_bids_for_segment!(
        treated_output::Matrix{Float64},
        data::Array{Float64, 3},
        seg::Int,
        virtual_reservoirs::Vector{Int},
        inputs::Inputs
    )

Process virtual reservoir bids for a specific segment and update the treated output array.
"""
function process_vr_bids_for_segment!(
    treated_output::Matrix{Float64},
    data::Array{Float64, 3},
    seg::Int,
    virtual_reservoirs::Vector{Int},
    inputs::Inputs,
)
    pair_index = 0
    for vr in virtual_reservoirs
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            pair_index += 1
            treated_output[seg, pair_index] = data[vr, ao, seg]
        end
    end
end

function run_time_file_suffixes(inputs::Inputs, run_time_options::RunTimeOptions)
    suffix = ""
    if !is_null(run_time_options.asset_owner_index)
        suffix *= "_asset_owner_$(run_time_options.asset_owner_index)"
    end
    if run_time_options.clearing_model_subproblem !== nothing
        suffix *= "_$(lowercase(string(run_time_options.clearing_model_subproblem)))"
    end
    if is_single_period(inputs)
        suffix *= "_period_$(inputs.args.period)"
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

function finalize_outputs!(outputs::OutputReaders)
    for output in values(outputs.outputs)
        Quiver.close!(output.reader)
    end
    return nothing
end
