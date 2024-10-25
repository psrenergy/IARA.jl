#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function apply_hour_subperiod_map(
    inputs,
    data::Array{T, N},
    unit::String,
    hour_dimension_index::Int,
) where {T, N}
    dimensions = size(data) |> collect
    dimensions[hour_dimension_index] = number_of_subperiods(inputs)
    new_data = zeros(T, dimensions...)

    return aggregate_data(inputs, data, new_data, subperiod_aggregation_type(unit), hour_dimension_index)
end

function aggregate_data(
    inputs,
    old_data::Array{T, 2},
    new_data::Array{T, 2},
    subperiod_aggregation_type::Configurations_SubperiodAggregationType.T,
    hour_dimension_index::Int,
) where {T}
    # For 2D data, hour_dimension_index should always be 2
    @assert hour_dimension_index == 2
    for subperiod in subperiods(inputs)
        hours_in_subperiod = subperiod_hour_map(inputs)[subperiod]
        if subperiod_aggregation_type == Configurations_SubperiodAggregationType.SUM
            new_data[:, subperiod] = sum(old_data[:, hour] for hour in hours_in_subperiod)
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.AVERAGE
            new_data[:, subperiod] = mean(old_data[:, hour] for hour in hours_in_subperiod)
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.LAST_VALUE
            new_data[:, subperiod] = old_data[:, hours_in_subperiod[end]]
        end
    end
    return new_data
end

function aggregate_data(
    inputs,
    old_data::Array{T, 3},
    new_data::Array{T, 3},
    subperiod_aggregation_type::Configurations_SubperiodAggregationType.T,
    hour_dimension_index::Int,
) where {T}
    # For 3D data, hour_dimension_index should always be 3
    @assert hour_dimension_index == 3
    for subperiod in subperiods(inputs)
        hours_in_subperiod = subperiod_hour_map(inputs)[subperiod]
        if subperiod_aggregation_type == Configurations_SubperiodAggregationType.SUM
            new_data[:, :, subperiod] = sum(old_data[:, :, hour] for hour in hours_in_subperiod)
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.AVERAGE
            new_data[:, :, subperiod] = mean(old_data[:, :, hour] for hour in hours_in_subperiod)
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.LAST_VALUE
            new_data[:, :, subperiod] = old_data[:, :, hours_in_subperiod[end]]
        end
    end
    return new_data
end

function aggregate_subperiods(
    inputs,
    old_data::Array{T, 2},
    subperiod_aggregation_type::Configurations_SubperiodAggregationType.T,
) where {T}
    new_data = zeros(T, size(old_data)[1:end-1]...)
    hours_in_subperiod = length.(subperiod_hour_map(inputs))
    all_hours_period = sum(hours_in_subperiod)
    for subperiod in subperiods(inputs)
        if subperiod_aggregation_type == Configurations_SubperiodAggregationType.SUM
            new_data[:] = sum(old_data[:, subperiod] for subperiod in subperiods(inputs))
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.AVERAGE
            new_data[:] =
                sum(old_data[:, subperiod] *
                    hours_in_subperiod[subperiod]
                    for subperiod in subperiods(inputs)) / all_hours_period
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.LAST_VALUE
            new_data[:] = old_data[:, subperiod]
        end
    end
    return new_data
end

function aggregate_subperiods(
    inputs,
    old_data::Array{T, 3},
    subperiod_aggregation_type::Configurations_SubperiodAggregationType.T,
) where {T}
    new_data = zeros(T, size(old_data)[1:end-1]...)
    hours_in_subperiod = length.(subperiod_hour_map(inputs))
    all_hours_period = sum(hours_in_subperiod)
    for subperiod in subperiods(inputs)
        if subperiod_aggregation_type == Configurations_SubperiodAggregationType.SUM
            new_data[:, :] = sum(old_data[:, :, subperiod] for subperiod in subperiods(inputs))
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.AVERAGE
            new_data[:, :] =
                sum(old_data[:, :, subperiod] *
                    hours_in_subperiod[subperiod]
                    for subperiod in subperiods(inputs)) / all_hours_period
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.LAST_VALUE
            new_data[:, :] = old_data[:, :, subperiod]
        end
    end
    return new_data
end

function aggregate_subperiods(
    inputs,
    old_data::Array{T, 4},
    subperiod_aggregation_type::Configurations_SubperiodAggregationType.T,
) where {T}
    hours_in_subperiod = length.(subperiod_hour_map(inputs))
    all_hours_period = sum(hours_in_subperiod)
    sizes_new_data = size.(Ref(old_data), [1, 3, 4])
    new_data = zeros(T, sizes_new_data...)
    for subperiod in subperiods(inputs)
        if subperiod_aggregation_type == Configurations_SubperiodAggregationType.SUM
            new_data = sum(old_data[:, subperiod, :, :] for subperiod in subperiods(inputs))
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.AVERAGE
            new_data =
                sum(old_data[:, subperiod, :, :] *
                    hours_in_subperiod[subperiod]
                    for subperiod in subperiods(inputs)) / all_hours_period
        elseif subperiod_aggregation_type == Configurations_SubperiodAggregationType.LAST_VALUE
            new_data = old_data[:, end, :, :]
        end
    end
    return new_data
end
