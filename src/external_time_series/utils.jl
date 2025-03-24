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
    ) where {T, N}

Write a time series file in Quiver format.

Required arguments:

  - `file_path::String`: Path to the CSV file.
  - `data::Array{T, N}`: Data to be written.
  - `dimensions::Vector{String}`: Dimensions of the data.
  - `labels::Vector{String}`: Labels of the data.
  - `time_dimension::String`: Name of the time dimension.
  - `dimension_size::Vector{Int}`: Size of each dimension.
  - `initial_date::Union{String, DateTime}`: Initial date of the time series. If a string is provided, it should be in the format "yyyy-mm-ddTHH:MM:SS".
  - `unit::String`: Unit of the time series data.
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
    frequency::String = "month",
    implementation::Type{<:Quiver.Implementation} = Quiver.csv,
) where {T, N}
    Quiver.array_to_file(
        file_path,
        data,
        implementation;
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

# Read an entire Quiver file
"""
    read_time_series_file(file_path::String)

Read a time series file, in either .csv or .quiv format.
"""
function read_timeseries_file(file_path::String)
    file_path_split = split(file_path, ".")
    if length(file_path_split) == 1
        error("File extension not found in $file_path. File extension should be .csv or .quiv.")
    end

    filepath = join(file_path_split[1:end-1], ".")

    if file_path_split[end] == "csv"
        return Quiver.file_to_array(filepath, Quiver.csv)
    elseif file_path_split[end] == "quiv"
        return Quiver.file_to_array(filepath, Quiver.binary)
    else
        error("Unexpected file extension: \"$(file_path_split[2])\". File extension should be .csv or .quiv.")
    end
end

function convert_time_series_file_to_binary(file_path::String)
    csv_file = file_path * ".csv"
    binary_file = file_path * ".quiv"
    num_errors = 0

    if isfile(binary_file)
        if isfile(csv_file)
            @error("Both CSV and binary files found for $file_path. Please remove one of them.")
            num_errors += 1
        else
            nothing
        end
    else
        if isfile(csv_file)
            temp_path = joinpath(dirname(file_path), "temp")
            if !isdir(temp_path)
                mkdir(temp_path)
            end
            Quiver.convert(file_path, Quiver.csv, Quiver.binary; destination_directory = temp_path)
        else
            @error("No CSV or binary file found for $file_path.")
            num_errors += 1
        end
    end

    return num_errors
end

function quiver_file_exists(file_path::String)
    return isfile(file_path * ".toml") && (isfile(file_path * ".quiv") || isfile(file_path * ".csv"))
end

function get_quiver_file_path(file_path::String)
    quiver_file_exists(file_path) || error("No Quiver file found for $file_path.")
    if isfile(file_path * ".quiv")
        return file_path * ".quiv"
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
    reader = Quiver.Reader{Quiver.csv}(file_path)

    # TODO this code is really bad. we should implement other ways of iterating through the file
    # TODO currently it only works for csv but it should work for any file type
    while reader.reader.next !== nothing
        Quiver.next_dimension!(reader)
        for i in eachindex(reader.data)
            if !isnan(reader.data[i])
                max_value = max(max_value, reader.data[i])
            end
        end
    end

    Quiver.close!(reader)
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

function get_dimension_dict_from_reader(reader::Quiver.Reader)
    dimensions_dict = Dict{Symbol, Int}()
    for (name, dimension) in zip(reader.metadata.dimensions, reader.metadata.dimension_size)
        dimensions_dict[name] = dimension
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
    filename::AbstractString,
    impl::Type{<:Quiver.Implementation};
    dimensions::Vector{String},
    labels::Vector{String},
    time_dimension::String,
    dimension_size::Vector{Int},
    initial_date::Union{String, DateTime} = "",
    unit::String = "",
    digits::Int = 6,
)
    file_created = 0
    quiver_impls = Quiver.implementations()
    for quiver_impl in quiver_impls
        filename_with_extensions =
            Quiver.add_extension_to_file(filename, Quiver.file_extension(quiver_impl))
        if isfile(filename_with_extensions)
            return file_created
        end
    end

    @assert all(dimension_size .> 0)

    @warn("Creating empty time series file at $(filename).")
    file_created = 1
    data = zeros(Float64, length(labels), reverse(dimension_size)...)
    Quiver.array_to_file(
        filename,
        data,
        impl;
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
