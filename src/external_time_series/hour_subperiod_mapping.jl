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
    HourSubperiodMapping

A struct to store the mapping between hours and subperiods. This struct is used to
store the mapping between hours and subperiods in the external time series data.
It only stores the mapping for one period at a time
"""
@kwdef mutable struct HourSubperiodMapping <: ViewFromExternalFile
    reader::Union{Quiver.Binary.File, Nothing} = nothing
    # Hours
    hour_subperiod_map::Vector{Int} = []
    # Subperiods
    subperiod_hour_map::Vector{Vector{Int}} = Vector{Int}[]
end

function initialize_hour_subperiod_mapping(inputs)
    num_errors = 0
    file_path = joinpath(path_case(inputs), hour_subperiod_map_file(inputs))

    # convert time series if needed
    num_errors += convert_time_series_file_to_binary(file_path)

    # Read file in the expected folder if it exists.
    # Otherwise, read from the temp folder.
    file_path = resolve_binary_file_path(file_path)
    reader = Quiver.Binary.open_file(file_path; mode = 'r')
    reader_metadata = Quiver.Binary.get_metadata(reader)

    if metadata_dimension_names(reader_metadata) != [:period, :hour]
        @error(
            "Hour-subperiod map file must have dimensions [period, hour]. Unexpected dimensions $(metadata_dimension_names(reader_metadata)).",
        )
        num_errors += 1
    end

    number_of_agents = length(Quiver.Binary.get_labels(reader_metadata))
    if number_of_agents != 1
        @error("Hour-subperiod map file must have only one agent. Unexpected number of agents $number_of_agents.")
        num_errors += 1
    end

    # Put reader on the struct
    inputs.time_series.hour_subperiod_mapping.reader = reader

    update_hour_subperiod_mapping!(inputs; period = 1)

    return num_errors
end

function update_hour_subperiod_mapping!(
    inputs;
    period::Int,
)
    reader = inputs.time_series.hour_subperiod_mapping.reader
    reader_metadata = Quiver.Binary.get_metadata(reader)
    # Hour subperiod map
    max_number_of_hours = metadata_max_index(reader_metadata, "hour")
    hour_subperiod_map = Int[]
    for hour in 1:max_number_of_hours
        subperiod = Quiver.Binary.read(reader; allow_nulls = true, period = period, hour = hour)[1]
        if isnan(subperiod)
            break
        end
        push!(hour_subperiod_map, subperiod)
    end
    number_of_hours = length(hour_subperiod_map)

    # Reverse hour subperiod map
    number_of_subperiods = maximum(hour_subperiod_map)
    subperiod_hour_map = Vector{Vector{Int}}(
        undef,
        number_of_subperiods,
    )
    for subperiod in 1:number_of_subperiods
        subperiod_hour_map[subperiod] = Int[]
    end
    for hour in 1:number_of_hours
        subperiod = hour_subperiod_map[hour]
        push!(subperiod_hour_map[subperiod], hour)
    end
    inputs.time_series.hour_subperiod_mapping.hour_subperiod_map = hour_subperiod_map
    inputs.time_series.hour_subperiod_mapping.subperiod_hour_map = subperiod_hour_map

    inputs.collections.configurations.subperiod_duration_in_hours =
        [length(subperiod_hour_map[subperiod]) for subperiod in subperiods(inputs)]

    return nothing
end
