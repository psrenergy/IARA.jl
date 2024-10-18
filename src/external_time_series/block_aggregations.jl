#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function apply_hour_block_map(
    inputs,
    data::Array{T, N},
    unit::String,
    hour_dimension_index::Int,
) where {T, N}
    dimensions = size(data) |> collect
    dimensions[hour_dimension_index] = number_of_blocks(inputs)
    new_data = zeros(T, dimensions...)

    return aggregate_data(inputs, data, new_data, block_aggregation_type(unit), hour_dimension_index)
end

function aggregate_data(
    inputs,
    old_data::Array{T, 2},
    new_data::Array{T, 2},
    block_aggregation_type::Configurations_BlockAggregationType.T,
    hour_dimension_index::Int,
) where {T}
    # For 2D data, hour_dimension_index should always be 2
    @assert hour_dimension_index == 2
    for block in blocks(inputs)
        hours_in_block = block_hour_map(inputs)[block]
        if block_aggregation_type == Configurations_BlockAggregationType.SUM
            new_data[:, block] = sum(old_data[:, hour] for hour in hours_in_block)
        elseif block_aggregation_type == Configurations_BlockAggregationType.AVERAGE
            new_data[:, block] = mean(old_data[:, hour] for hour in hours_in_block)
        elseif block_aggregation_type == Configurations_BlockAggregationType.LAST_VALUE
            new_data[:, block] = old_data[:, hours_in_block[end]]
        end
    end
    return new_data
end

function aggregate_data(
    inputs,
    old_data::Array{T, 3},
    new_data::Array{T, 3},
    block_aggregation_type::Configurations_BlockAggregationType.T,
    hour_dimension_index::Int,
) where {T}
    # For 3D data, hour_dimension_index should always be 3
    @assert hour_dimension_index == 3
    for block in blocks(inputs)
        hours_in_block = block_hour_map(inputs)[block]
        if block_aggregation_type == Configurations_BlockAggregationType.SUM
            new_data[:, :, block] = sum(old_data[:, :, hour] for hour in hours_in_block)
        elseif block_aggregation_type == Configurations_BlockAggregationType.AVERAGE
            new_data[:, :, block] = mean(old_data[:, :, hour] for hour in hours_in_block)
        elseif block_aggregation_type == Configurations_BlockAggregationType.LAST_VALUE
            new_data[:, :, block] = old_data[:, :, hours_in_block[end]]
        end
    end
    return new_data
end

function aggregate_blocks(
    inputs,
    old_data::Array{T, 2},
    block_aggregation_type::Configurations_BlockAggregationType.T,
) where {T}
    new_data = zeros(T, size(old_data)[1:end-1]...)
    hours_in_block = length.(block_hour_map(inputs))
    all_hours_stage = sum(hours_in_block)
    for block in blocks(inputs)
        if block_aggregation_type == Configurations_BlockAggregationType.SUM
            new_data[:] = sum(old_data[:, block] for block in blocks(inputs))
        elseif block_aggregation_type == Configurations_BlockAggregationType.AVERAGE
            new_data[:] = sum(old_data[:, block] *
                              hours_in_block[block]
                              for block in blocks(inputs)) / all_hours_stage
        elseif block_aggregation_type == Configurations_BlockAggregationType.LAST_VALUE
            new_data[:] = old_data[:, block]
        end
    end
    return new_data
end

function aggregate_blocks(
    inputs,
    old_data::Array{T, 3},
    block_aggregation_type::Configurations_BlockAggregationType.T,
) where {T}
    new_data = zeros(T, size(old_data)[1:end-1]...)
    hours_in_block = length.(block_hour_map(inputs))
    all_hours_stage = sum(hours_in_block)
    for block in blocks(inputs)
        if block_aggregation_type == Configurations_BlockAggregationType.SUM
            new_data[:, :] = sum(old_data[:, :, block] for block in blocks(inputs))
        elseif block_aggregation_type == Configurations_BlockAggregationType.AVERAGE
            new_data[:, :] =
                sum(old_data[:, :, block] *
                    hours_in_block[block]
                    for block in blocks(inputs)) / all_hours_stage
        elseif block_aggregation_type == Configurations_BlockAggregationType.LAST_VALUE
            new_data[:, :] = old_data[:, :, block]
        end
    end
    return new_data
end

function aggregate_blocks(
    inputs,
    old_data::Array{T, 4},
    block_aggregation_type::Configurations_BlockAggregationType.T,
) where {T}
    hours_in_block = length.(block_hour_map(inputs))
    all_hours_stage = sum(hours_in_block)
    sizes_new_data = size.(Ref(old_data), [1, 3, 4])
    new_data = zeros(T, sizes_new_data...)
    for block in blocks(inputs)
        if block_aggregation_type == Configurations_BlockAggregationType.SUM
            new_data = sum(old_data[:, block, :, :] for block in blocks(inputs))
        elseif block_aggregation_type == Configurations_BlockAggregationType.AVERAGE
            new_data =
                sum(old_data[:, block, :, :] *
                    hours_in_block[block]
                    for block in blocks(inputs)) / all_hours_stage
        elseif block_aggregation_type == Configurations_BlockAggregationType.LAST_VALUE
            new_data = old_data[:, end, :, :]
        end
    end
    return new_data
end
