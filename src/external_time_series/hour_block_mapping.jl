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
    HourBlockMapping

A struct to store the mapping between hours and blocks. This struct is used to
store the mapping between hours and blocks in the external time series data.
It only stores the mapping for one stage at a time
"""
@kwdef mutable struct HourBlockMapping <: ViewFromExternalFile
    reader::Union{Quiver.Reader{Quiver.binary}, Nothing} = nothing
    # Hours
    hour_block_map::Vector{Int} = []
    # Blocks
    block_hour_map::Vector{Vector{Int}} = Vector{Int}[]
end

function initialize_hour_block_mapping(inputs)
    num_errors = 0
    file_path = joinpath(path_case(inputs), hour_block_map_file(inputs))

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
    reader = Quiver.Reader{Quiver.binary}(file_path)

    if reader.metadata.dimensions != [:stage, :hour]
        @error(
            "Hour-block map file must have dimensions [stage, hour]. Unexpected dimensions $(reader.metadata.dimensions).",
        )
        num_errors += 1
    end

    number_of_agents = length(reader.labels_to_read)
    if number_of_agents != 1
        @error("Hour-block map file must have only one agent. Unexpected number of agents $number_of_agents.")
        num_errors += 1
    end

    # Put reader on the struct
    inputs.time_series.hour_block_mapping.reader = reader

    update_hour_block_mapping!(inputs; stage = 1)

    return num_errors
end

function update_hour_block_mapping!(
    inputs;
    stage::Int,
)
    reader = inputs.time_series.hour_block_mapping.reader
    # Hour block map
    max_number_of_hours = Quiver.max_index(reader, "hour")
    hour_block_map = Int[]
    for hour in 1:max_number_of_hours
        Quiver.goto!(reader; stage = stage, hour = hour)
        block = reader.data[1]
        if isnan(block)
            break
        end
        push!(hour_block_map, block)
    end
    number_of_hours = length(hour_block_map)

    # Reverse hour block map
    number_of_blocks = maximum(hour_block_map)
    block_hour_map = Vector{Vector{Int}}(
        undef,
        number_of_blocks,
    )
    for block in 1:number_of_blocks
        block_hour_map[block] = Int[]
    end
    for hour in 1:number_of_hours
        block = hour_block_map[hour]
        push!(block_hour_map[block], hour)
    end
    inputs.time_series.hour_block_mapping.hour_block_map = hour_block_map
    inputs.time_series.hour_block_mapping.block_hour_map = block_hour_map

    inputs.collections.configurations.block_duration_in_hours =
        [length(block_hour_map[block]) for block in blocks(inputs)]

    return nothing
end
