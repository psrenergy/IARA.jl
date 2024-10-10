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
    TimeSeriesView{T, N}

Collection representing the time series data read from external files in chunks.
"""
@kwdef mutable struct TimeSeriesView{T, N} <: ViewFromExternalFile
    reader::Union{Quiver.Reader{Quiver.binary}, Nothing} = nothing
    data::Array{T, N} = Array{T, N}(undef, zeros(Int, N)...)
end

function Base.getindex(time_series::TimeSeriesView{T, N}, inds...) where {T, N}
    return getindex(time_series.data, inds...)
end

function Base.size(time_series::TimeSeriesView{T, N}) where {T, N}
    return size(time_series.data)
end

function initialize_time_series_view_from_external_file(
    ts::TimeSeriesView{T, N},
    inputs,
    file_path::AbstractString;
    expected_unit::String = "",
    labels_to_read::Vector{String} = String[],
) where {T, N}
    num_errors = 0

    # convert time series if needed
    num_errors += convert_time_series_file_to_binary(file_path)

    # Read file in the expected folder if it exists.
    # Otherwise, read from the temp folder.
    file_path = if isfile(file_path * ".quiv")
        file_path
    else
        file_name = basename(file_path)
        file_dir = dirname(file_path)
        joinpath(file_dir, "temp", file_name)
    end

    # Initialize time series
    ts.reader = Quiver.Reader{Quiver.binary}(
        file_path;
        carrousel = true,
        labels_to_read,
    )

    # Validate if unit came as expected
    if !isempty(expected_unit) && (ts.reader.metadata.unit != expected_unit)
        @error(
            "Unit of time series file $(file_path) is $(ts.reader.metadata.unit). This is different from the expected unit $expected_unit.",
        )
        num_errors += 1
    end

    # Validate if initial date is before the initial date of the problem
    if ts.reader.metadata.initial_date > initial_date_time(inputs)
        @error(
            "Initial date of time series file $(file_path) is $(metadata.initial_date). This is after the initial date of the problem: $(initial_date_time(inputs))",
        )
        num_errors += 1
    end

    # Initialize dynamic time series
    ts.data = read_time_series_view_from_external_file(
        inputs, ts.reader;
        stage = 1, scenario = 1, data_type = eltype(ts.data),
    )

    return num_errors
end

function read_time_series_view_from_external_file(
    inputs,
    reader::Quiver.Reader{Quiver.binary};
    stage::Int,
    scenario::Int,
    data_type::Type,
)
    # TODO check if this function is good enough
    # Some ideas could be to create enumerables of types of variations and have a specific function 
    # for each one of them. This does not seem as a too bad idea.

    # Check if file has stage and scenario dimensions
    stage_scenario_kwargs = OrderedDict()
    dimension_names = reverse(reader.metadata.dimensions)
    dimension_sizes = reverse(reader.metadata.dimension_size)
    stage_dimension_index = findfirst(isequal(:stage), dimension_names)
    if stage_dimension_index !== nothing
        date_time_to_read = date_time_from_stage(inputs, stage)
        file_stage = stage_from_date_time(inputs, date_time_to_read; initial_date_time = reader.metadata.initial_date)
        stage_scenario_kwargs[:stage] = file_stage
        deleteat!(dimension_names, stage_dimension_index)
        deleteat!(dimension_sizes, stage_dimension_index)
    end
    scenario_dimension_index = findfirst(isequal(:scenario), dimension_names)
    if scenario_dimension_index !== nothing
        stage_scenario_kwargs[:scenario] = scenario
        deleteat!(dimension_names, scenario_dimension_index)
        deleteat!(dimension_sizes, scenario_dimension_index)
    end

    # Read data
    # TODO we could read it directly in to the dynamic time series
    # instead of initializing an array and then copying it.
    # We could also make a new version of this fucntion that receives the vector it is 
    # going to fill as an argument.
    data = zeros(
        data_type,
        length(reader.labels_to_read),
        dimension_sizes...,
    )
    for dims in Iterators.product([1:size for size in dimension_sizes]...)
        dim_kwargs = OrderedDict(Symbol.(dimension_names) .=> dims)
        Quiver.goto!(reader; stage_scenario_kwargs..., dim_kwargs...)
        data[:, dims...] = reader.data
    end

    if :hour in dimension_names
        if !has_hour_block_map(inputs)
            error("File $(reader.filename) has hourly data but an hour-block map was not defined.")
        end
        hour_dimension_index = findfirst(isequal(:hour), dimension_names) + 1 # add one due to agent dimension
        data = apply_hour_block_map(inputs, data, reader.metadata.unit, hour_dimension_index)
    end

    return data
end
