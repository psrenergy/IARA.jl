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
    write_timeseries_file(
        file_path::String,
        data::Array{T, N};
        dimensions::Vector{String},
        labels::Vector{String},
        time_dimension::String,
        dimension_size::Vector{Int},
        initial_date::Union{String, DateTime} = "",
        unit::String = "",
        frequency::String = "monthly",
    ) where {T, N}

Write a time series file in Quiver binary format.

Required arguments:

  - `file_path::String`: Path to the binary file.
  - `data::Array{T, N}`: Data to be written.
  - `dimensions::Vector{String}`: Dimensions of the data.
  - `labels::Vector{String}`: Labels of the data.
  - `time_dimension::String`: Name of the time dimension.
  - `dimension_size::Vector{Int}`: Size of each dimension.
  - `initial_date::Union{String, DateTime}`: Initial date of the time series. If a string is provided, it should be in the format "yyyy-mm-ddTHH:MM:SS".
  - `unit::String`: Unit of the time series data.
  - `frequency::String`: Time interval between data points ("yearly", "monthly", "weekly", "daily", or "hourly").
"""
function write_timeseries_file(
    file_path::String,
    data::Array{T, N};
    dimensions::Vector{String},
    labels::Vector{String},
    time_dimension::String,
    dimension_size::Vector{Int},
    initial_date::Union{String, DateTime} = "",
    unit::String = "",
    frequency::String = "monthly",
) where {T, N}
    array_to_binary_file(
        file_path,
        data;
        dimensions,
        labels,
        time_dimension,
        dimension_size,
        initial_date,
        unit,
        frequency,
        digits = 6,
    )
    return nothing
end

"""
    read_timeseries_file(file_path::String)

Read a time series file. `.csv` inputs are converted to binary first via
`convert_time_series_file_to_binary`.
"""
function read_timeseries_file(file_path::String)
    file_path_split = split(file_path, ".")
    if length(file_path_split) == 1
        error("File extension not found in $file_path. File extension should be .csv or .qvr.")
    end

    filepath = join(file_path_split[1:end-1], ".")
    ext = file_path_split[end]

    if ext == "qvr"
        return binary_file_to_array(filepath)
    elseif ext == "csv"
        convert_time_series_file_to_binary(filepath)
        return binary_file_to_array(resolve_binary_file_path(filepath))
    else
        error("Unexpected file extension: \"$ext\". Expected .csv or .qvr.")
    end
end

function convert_time_series_file_to_binary(file_path::String)
    csv_file = file_path * ".csv"
    binary_file = file_path * ".qvr"
    num_errors = 0

    if !isfile(binary_file)
        if isfile(csv_file)
            temp_path = joinpath(dirname(file_path), "temp")
            if !isdir(temp_path)
                mkdir(temp_path)
            end
            temp_file_path = joinpath(temp_path, basename(file_path))
            cp(csv_file, temp_file_path * ".csv"; force = true)
            cp(file_path * ".toml", temp_file_path * ".toml"; force = true)
            Quiver.Binary.csv_to_bin(temp_file_path)
        else
            @error("No CSV or binary file found for $file_path.")
            num_errors += 1
        end
    end

    return num_errors
end

"""
    resolve_binary_file_path(file_path::String)

Given `file_path` (no extension) whose Quiver binary version is already guaranteed to exist
somewhere — either directly at `file_path` or converted into `dirname(file_path)/temp/` by an
earlier `convert_time_series_file_to_binary` call — return the base path (still no extension)
of wherever the `.qvr` actually lives.
"""
function resolve_binary_file_path(file_path::String)
    if isfile(file_path * ".qvr")
        return file_path
    else
        return joinpath(dirname(file_path), "temp", basename(file_path))
    end
end

function quiver_file_exists(file_path::String)
    return isfile(file_path * ".toml") && (isfile(file_path * ".qvr") || isfile(file_path * ".csv"))
end

function get_quiver_file_path(file_path::String)
    quiver_file_exists(file_path) || error("No Quiver file found for $file_path.")
    if isfile(file_path * ".qvr")
        return file_path * ".qvr"
    elseif isfile(file_path * ".csv")
        return file_path * ".csv"
    end
end

# Function to check if any of the files in the list exist
function find_file(file_paths::Vector{String})
    for path in file_paths
        if quiver_file_exists(path)
            return path
        end
    end
    return nothing
end

function delete_temp_files(inputs)
    directories_to_delete = String[]
    for (root, dirs, files) in walkdir(path_case(inputs))
        for dir in dirs
            if dir == "temp"
                push!(directories_to_delete, joinpath(root, dir))
            end
        end
    end
    for dir in directories_to_delete
        rm(dir; recursive = true)
    end
    return nothing
end

function get_maximum_value_of_time_series(file_path::String)
    max_value = -Inf

    # convert time series if needed
    num_errors = convert_time_series_file_to_binary(file_path)

    # When the file does not exist we must exit this function early
    if num_errors > 0
        error("Could not read time series file $file_path.")
    end
    file_path = resolve_binary_file_path(file_path)

    reader = Quiver.Binary.open_file(file_path; mode = 'r')
    md = Quiver.Binary.get_metadata(reader)
    dimension_names = metadata_dimension_names(md)
    dimension_sizes = metadata_dimension_sizes(md)

    dims = first_position!(copy(dimension_sizes))
    names_tuple = Tuple(dimension_names)
    for _ in 1:prod(dimension_sizes)
        next_dim!(dims, dimension_sizes)
        read_kwargs = NamedTuple{names_tuple}(Tuple(dims))
        data = Quiver.Binary.read(reader; allow_nulls = true, read_kwargs...)
        for value in data
            if !isnan(value)
                max_value = max(max_value, value)
            end
        end
    end

    Quiver.Binary.close!(reader)
    return max_value
end

function bidding_group_file_labels(inputs)
    labels = String[]
    for bg in bidding_group_label(inputs)
        for bus in bus_label(inputs)
            push!(labels, "$bg - $bus")
        end
    end
    return labels
end

function get_dimension_dict_from_reader(reader::Quiver.Binary.File)
    md = Quiver.Binary.get_metadata(reader)
    dimensions_dict = Dict{Symbol, Int}()
    for (name, size) in zip(metadata_dimension_names(md), metadata_dimension_sizes(md))
        dimensions_dict[name] = size
    end
    return dimensions_dict
end

function virtual_reservoir_file_labels(inputs)
    labels = String[]
    for vr in index_of_elements(inputs, VirtualReservoir)
        for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
            push!(labels, "$(virtual_reservoir_label(inputs, vr)) - $(asset_owner_label(inputs, ao))")
        end
    end
    return labels
end

function create_empty_time_series_if_necessary(
    filename::AbstractString;
    dimensions::Vector{String},
    labels::Vector{String},
    time_dimension::String,
    dimension_size::Vector{Int},
    initial_date::Union{String, DateTime} = "",
    unit::String = "",
    digits::Int = 6,
)
    file_created = 0
    if isfile(filename * ".qvr")
        return file_created
    end

    @assert all(dimension_size .> 0)

    @warn("Creating empty time series file at $(filename).")
    file_created = 1
    data = zeros(Float64, length(labels), reverse(dimension_size)...)
    array_to_binary_file(
        filename,
        data;
        dimensions,
        labels,
        time_dimension,
        dimension_size,
        initial_date,
        unit,
        digits,
    )
    return file_created
end

has_subscenario(reader::Quiver.Binary.File) =
    :subscenario in metadata_dimension_names(Quiver.Binary.get_metadata(reader))

"""
    next_dim!(current_dimensions::Vector{Int}, max_size_dimensions::Vector{Int})

Advance `current_dimensions` to the next position in column-major (last-index-fastest) order,
in place.
"""
function next_dim!(
    current_dimensions::Vector{Int},
    max_size_dimensions::Vector{Int},
)
    for i in length(current_dimensions):-1:1
        if current_dimensions[i] < max_size_dimensions[i]
            current_dimensions[i] += 1
            for j in (i+1):length(current_dimensions)
                current_dimensions[j] = 1
            end
            return
        end
    end
    return
end

"""
    first_position!(max_size_dimensions::Vector{Int})

Return the starting position for a `next_dim!` iteration — one before the first valid
coordinate, so the first `next_dim!` call lands on `[1, 1, ..., 1]`.
"""
function first_position!(
    max_size_dimensions::Vector{Int},
)
    dims = fill(1, length(max_size_dimensions))
    dims[end] = 0
    return dims
end

"""
    metadata_dimension_names(md::Quiver.Binary.Metadata)

Return the dimension names of a Quiver binary metadata handle as a `Vector{Symbol}`.
"""
function metadata_dimension_names(md::Quiver.Binary.Metadata)
    return [Symbol(d.name) for d in Quiver.Binary.get_dimensions(md)]
end

"""
    metadata_dimension_sizes(md::Quiver.Binary.Metadata)

Return the dimension sizes of a Quiver binary metadata handle as a `Vector{Int}`.
"""
function metadata_dimension_sizes(md::Quiver.Binary.Metadata)
    return [Int(d.size) for d in Quiver.Binary.get_dimensions(md)]
end

"""
    metadata_max_index(md::Quiver.Binary.Metadata, dimension::String)

Return the size of the named dimension.
"""
function metadata_max_index(md::Quiver.Binary.Metadata, dimension::String)
    for d in Quiver.Binary.get_dimensions(md)
        if d.name == dimension
            return Int(d.size)
        end
    end
    return error("Dimension $dimension not found in metadata")
end

"""
    carrousel_read(file::Quiver.Binary.File, md::Quiver.Binary.Metadata; dims...)

Read from `file` with cyclic wraparound on every dimension. `dims` uses 1-based indices
exactly like `Quiver.Binary.read`; each index is wrapped with `mod1` against that dimension's
size before the actual read. Passes `allow_nulls = true` since `NaN` is a legitimate
missing-value sentinel in IARA's time series.
"""
function carrousel_read(file::Quiver.Binary.File, md::Quiver.Binary.Metadata; dims...)
    dimension_sizes = Dict(d.name => Int(d.size) for d in Quiver.Binary.get_dimensions(md))
    wrapped_dims = NamedTuple(
        Symbol(name) => mod1(value, dimension_sizes[String(name)]) for (name, value) in pairs(dims)
    )
    return Quiver.Binary.read(file; allow_nulls = true, wrapped_dims...)
end

"""
    label_indices_for(md::Quiver.Binary.Metadata, labels_to_read::Vector{String})

Return the index of each `labels_to_read` entry within `md`'s label set, for filtering/reordering
a full-row `Quiver.Binary.read`/`carrousel_read` result down to just the requested labels. Errors
if any requested label is not found in the file.
"""
function label_indices_for(md::Quiver.Binary.Metadata, labels_to_read::Vector{String})
    file_labels = Quiver.Binary.get_labels(md)
    indices = indexin(labels_to_read, file_labels)
    missing_mask = isnothing.(indices)
    if any(missing_mask)
        error("Label(s) $(labels_to_read[missing_mask]) not found in metadata labels $(file_labels)")
    end
    return Int.(indices)
end

"""
    quiver_initial_datetime_string(initial_date::Union{String, DateTime})

Convert `initial_date` to the full "yyyy-mm-ddTHH:MM:SS" string `Quiver.Binary.Metadata` requires.
"""
function quiver_initial_datetime_string(initial_date::Union{String, DateTime})
    if initial_date isa DateTime
        return Quiver.date_time_to_string(initial_date)
    elseif isempty(initial_date)
        return initial_date
    else
        return Quiver.date_time_to_string(DateTime(initial_date, "yyyy-mm-ddTHH:MM:SS"))
    end
end

"""
    array_to_binary_file(filename::String, data::Array{T, N};
        dimensions::Vector{String}, labels::Vector{String}, dimension_size::Vector{Int},
        time_dimension::String = "", initial_date::Union{String, DateTime} = "", unit::String = "",
        frequency::String = "", digits::Union{Int, Nothing} = nothing) where {T, N}

Write a whole in-memory array to a new binary file in one call.
"""
function array_to_binary_file(
    filename::String,
    data::Array{T, N};
    dimensions::Vector{String},
    labels::Vector{String},
    dimension_size::Vector{Int},
    time_dimension::String = "",
    initial_date::Union{String, DateTime} = "",
    unit::String = "",
    frequency::String = "",
    digits::Union{Int, Nothing} = nothing,
) where {T, N}
    if !isempty(frequency) && isempty(time_dimension)
        error("frequency was given but time_dimension was not")
    end
    if !isempty(time_dimension) && !(time_dimension in dimensions)
        error("time_dimension \"$time_dimension\" not found in dimensions $dimensions")
    end
    md = Quiver.Binary.Metadata(;
        initial_datetime = quiver_initial_datetime_string(initial_date),
        unit = unit,
        labels = labels,
        dimensions = dimensions,
        dimension_sizes = dimension_size,
        time_dimensions = isempty(time_dimension) ? String[] : [time_dimension],
        frequencies = isempty(frequency) ? String[] : [frequency],
    )
    writer = Quiver.Binary.open_file(filename; mode = 'w', metadata = md)

    dims = first_position!(copy(dimension_size))
    names_tuple = Tuple(Symbol.(dimensions))
    for _ in 1:prod(dimension_size)
        next_dim!(dims, dimension_size)
        row = data[:, reverse(dims)...]
        row = digits === nothing ? row : round.(row; digits = digits)
        read_kwargs = NamedTuple{names_tuple}(Tuple(dims))
        Quiver.Binary.write!(writer; data = row, read_kwargs...)
    end
    Quiver.Binary.close!(writer)
    return nothing
end

"""
    binary_file_to_array(filename::String)

Read a whole binary file into an in-memory array, returning `(data, metadata)`.
"""
function binary_file_to_array(filename::String)
    reader = Quiver.Binary.open_file(filename; mode = 'r')
    md = Quiver.Binary.get_metadata(reader)
    labels = Quiver.Binary.get_labels(md)
    dimension_size = metadata_dimension_sizes(md)
    dimension_names = metadata_dimension_names(md)

    data = zeros(Float64, length(labels), reverse(dimension_size)...)
    dims = first_position!(copy(dimension_size))
    names_tuple = Tuple(dimension_names)
    for _ in 1:prod(dimension_size)
        next_dim!(dims, dimension_size)
        read_kwargs = NamedTuple{names_tuple}(Tuple(dims))
        data[:, reverse(dims)...] = Quiver.Binary.read(reader; allow_nulls = true, read_kwargs...)
    end
    Quiver.Binary.close!(reader)
    return data, md
end
