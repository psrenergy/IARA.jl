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
    reader::Union{Quiver.Binary.File, Nothing} = nothing
    # Data that is mapped from the exact dimensions of the file, eg period, scenario, hour
    exact_dimensions_data::Array{T, N} = Array{T, N}(undef, zeros(Int, N)...)
    # Data that will be used in the model and could be aggregated at some point
    data::Array{T, N} = Array{T, N}(undef, zeros(Int, N)...)
    dimensions::Vector{Symbol} = Symbol[]
    label_indices::Vector{Int} = Int[]
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
    possible_expected_dimensions::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}(),
    labels_to_read::Vector{String} = String[],
) where {T, N}
    num_errors = 0

    # convert time series if needed
    num_errors += convert_time_series_file_to_binary(file_path)

    # When the file does not exist we must exit this function early
    if num_errors > 0
        return num_errors
    end

    # Read file in the expected folder if it exists.
    # Otherwise, read from the temp folder.
    file_path = resolve_binary_file_path(file_path)

    # Initialize time series
    ts.reader = Quiver.Binary.open_file(file_path; mode = 'r')
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    ts.label_indices = label_indices_for(ts_metadata, labels_to_read)

    # Validate if unit came as expected
    reader_unit = Quiver.Binary.get_unit(ts_metadata)
    if !isempty(expected_unit) && (reader_unit != expected_unit)
        @error(
            "Unit of time series file $(file_path) is $(reader_unit). This is different from the expected unit $expected_unit.",
        )
        num_errors += 1
    end

    # Validate if initial date is before the initial date of the problem
    reader_initial_date = Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata))
    if reader_initial_date > initial_date_time(inputs)
        @error(
            "Initial date of time series file $(file_path) is $(reader_initial_date). This is after the initial date of the problem: $(initial_date_time(inputs))",
        )
        num_errors += 1
    end

    ts.dimensions = metadata_dimension_names(ts_metadata)
    # Validate if the dimensions are as expected
    if !isempty(possible_expected_dimensions)
        # Iterate through all possible dimensions and check if the time series
        # is defined in one of them.
        dimension_is_valid = false
        for possible_dimensions in possible_expected_dimensions
            if ts.dimensions == possible_dimensions
                dimension_is_valid = true
                break
            end
        end
        if !dimension_is_valid
            error_msg = "Time series file $(file_path) has dimensions $(ts.dimensions). This is different from the possible dimensions of this file $possible_expected_dimensions."
            for possible_dimensions in possible_expected_dimensions
                if ts.dimensions[2:end] == possible_dimensions[2:end]
                    error_msg *= " If the dimensions differ only between :period and :season, you might have defined the wrong Configurations_PolicyGraphType in the configurations."
                    error_msg *= " Cyclic policy graphs should have :season as the first dimension in the data, while linear policy graphs should have :period as the first dimension."
                    break
                end
            end
            @error(error_msg)
            num_errors += 1
        end
    end

    # Allocate the array of correct size based on the dimension sizes of extra dimensions
    dimension_names = reverse(metadata_dimension_names(ts_metadata))
    dimension_sizes = reverse(metadata_dimension_sizes(ts_metadata))
    period_dimension_index = findfirst(isequal(:period), dimension_names)
    if period_dimension_index !== nothing
        deleteat!(dimension_sizes, period_dimension_index)
    end
    season_dimension_index = findfirst(isequal(:season), dimension_names)
    if season_dimension_index !== nothing
        deleteat!(dimension_sizes, season_dimension_index)
    end
    scenario_dimension_index = findfirst(isequal(:scenario), dimension_names)
    if scenario_dimension_index !== nothing
        deleteat!(dimension_sizes, scenario_dimension_index)
    end
    sample_dimension_index = findfirst(isequal(:sample), dimension_names)
    if sample_dimension_index !== nothing
        number_of_samples = dimension_sizes[sample_dimension_index]
        if number_of_samples != number_of_scenarios(inputs) && number_of_samples != 1
            @warn(
                "Time series file $(file_path) has $(dimension_sizes[sample_dimension_index]) samples" *
                ", but the problem has $(number_of_scenarios(inputs)) scenario(s). " *
                "This might lead to different samples being weighted differently.",
            )
        end
        deleteat!(dimension_sizes, sample_dimension_index)
    end

    ts.exact_dimensions_data = zeros(
        T,
        length(labels_to_read),
        dimension_sizes...,
    )

    # Initialize dynamic time series
    read_time_series_view_from_external_file!(
        inputs,
        ts;
        period = 1,
        scenario = 1,
    )

    return num_errors
end

function read_time_series_view_from_external_file!(
    inputs,
    ts::TimeSeriesView{T, N};
    period::Int,
    scenario::Int,
) where {T, N}
    # Here we must have one function for each variation of dimensions
    if ts.dimensions == [:period, :scenario, :subperiod]
        read_period_scenario_subperiod!(
            inputs,
            ts,
            period,
            scenario,
        )
    elseif ts.dimensions == [:period, :scenario, :hour]
        read_period_scenario_hour!(
            inputs,
            ts,
            period,
            scenario,
        )
    elseif ts.dimensions == [:period, :scenario, :subscenario, :subperiod]
        read_period_scenario_subscenario_subperiod!(
            inputs,
            ts,
            period,
            scenario,
        )
    elseif ts.dimensions == [:period, :scenario, :subscenario]
        read_period_scenario_subscenario!(
            inputs,
            ts,
            period,
            scenario,
        )
    elseif ts.dimensions == [:period, :scenario, :profile]
        read_period_scenario_profile!(
            inputs,
            ts,
            period,
            scenario,
        )
    elseif ts.dimensions == [:period, :subperiod]
        read_period_subperiod!(
            inputs,
            ts,
            period,
        )
    elseif ts.dimensions == [:period, :profile]
        read_period_profile!(
            inputs,
            ts,
            period,
        )
    elseif ts.dimensions == [:period, :profile, :complementary_group]
        read_period_profile_complementary_group!(
            inputs,
            ts,
            period,
        )
    elseif ts.dimensions == [:period, :scenario]
        read_period_scenario!(
            inputs,
            ts,
            period,
            scenario,
        )
    elseif ts.dimensions == [:inflow_period, :lag]
        read_inflow_period_lag!(
            inputs,
            ts,
        )
    elseif ts.dimensions == [:inflow_period]
        read_inflow_period!(
            inputs,
            ts,
        )
    elseif ts.dimensions == [:season, :sample, :subscenario, :subperiod]
        season, sample, _ = consult_period_season_map(inputs; period, scenario)
        read_season_sample_subscenario_subperiod!(
            inputs,
            ts;
            season,
            sample,
        )
    elseif ts.dimensions == [:season, :sample, :subperiod]
        season, sample, _ = consult_period_season_map(inputs; period, scenario)
        read_season_sample_subperiod!(
            inputs,
            ts;
            season,
            sample,
        )
    elseif ts.dimensions == [:season, :sample, :subscenario]
        season, sample, _ = consult_period_season_map(inputs; period, scenario)
        read_season_sample_subscenario!(
            inputs,
            ts;
            season,
            sample,
        )
    elseif ts.dimensions == [:period]
        read_period!(
            inputs,
            ts,
            period,
        )
    elseif ts.dimensions == [:scenario, :lag]
        read_scenario_lag!(
            inputs,
            ts,
            scenario,
        )
    elseif ts.dimensions == [:sample, :lag]
        _, sample, _ = consult_period_season_map(inputs; period, scenario)
        read_sample_lag!(
            inputs,
            ts,
            sample,
        )
    elseif ts.dimensions == [:scenario]
        read_scenario!(
            inputs,
            ts,
            scenario,
        )
    elseif ts.dimensions == [:season, :sample]
        season, sample, _ = consult_period_season_map(inputs; period, scenario)
        read_season_sample!(
            inputs,
            ts;
            season,
            sample,
        )
    else
        error("Time series with dimensions $(ts.dimensions) not supported.")
    end
    return nothing
end

function read_period_scenario_subperiod!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
    scenario::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    # Loop in subperiods
    for subperiod in 1:metadata_dimension_sizes(ts_metadata)[3]
        ts.exact_dimensions_data[:, subperiod] =
            carrousel_read(ts.reader, ts_metadata; period = file_period, scenario, subperiod)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_period_scenario_hour!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
    scenario::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    # Loop in hours
    for hour in 1:metadata_dimension_sizes(ts_metadata)[3]
        ts.exact_dimensions_data[:, hour] =
            carrousel_read(ts.reader, ts_metadata; period = file_period, scenario, hour)[ts.label_indices]
    end
    if !has_hour_subperiod_map(inputs)
        error("File $(reader.filename) has hourly data but an hour-subperiod map was not defined.")
    end
    hour_dimension_index = 2
    ts.data = apply_hour_subperiod_map(
        inputs,
        ts.exact_dimensions_data,
        Quiver.Binary.get_unit(ts_metadata),
        hour_dimension_index,
    )
    return nothing
end

function read_period_scenario_subscenario_subperiod!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
    scenario::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    dimension_sizes = metadata_dimension_sizes(ts_metadata)
    # Loop in subperiods
    for subperiod in 1:dimension_sizes[4],
        subscenario in 1:dimension_sizes[3]

        ts.exact_dimensions_data[:, subperiod, subscenario] =
            carrousel_read(ts.reader, ts_metadata; period = file_period, scenario, subscenario, subperiod)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_period_scenario_subscenario!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
    scenario::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    # Loop in subperiods
    for subscenario in 1:metadata_dimension_sizes(ts_metadata)[3]
        ts.exact_dimensions_data[:, subscenario] =
            carrousel_read(ts.reader, ts_metadata; period = file_period, scenario, subscenario)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_period_scenario_profile!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
    scenario::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    for profile in 1:metadata_dimension_sizes(ts_metadata)[3]
        ts.exact_dimensions_data[:, profile] =
            carrousel_read(ts.reader, ts_metadata; period = file_period, scenario, profile)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_period_subperiod!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    # Loop in subperiods
    for subperiod in 1:metadata_dimension_sizes(ts_metadata)[2]
        ts.exact_dimensions_data[:, subperiod] =
            carrousel_read(ts.reader, ts_metadata; period = file_period, subperiod)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_period_profile!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    for profile in 1:metadata_dimension_sizes(ts_metadata)[2]
        ts.exact_dimensions_data[:, profile] =
            carrousel_read(ts.reader, ts_metadata; period = file_period, profile)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_period_profile_complementary_group!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    dimension_sizes = metadata_dimension_sizes(ts_metadata)
    for complementary_group in 1:dimension_sizes[3],
        profile in 1:dimension_sizes[2]

        ts.exact_dimensions_data[:, complementary_group, profile] =
            carrousel_read(ts.reader, ts_metadata; period = file_period, profile, complementary_group)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_period_scenario!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
    scenario::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    ts.exact_dimensions_data = carrousel_read(ts.reader, ts_metadata; period = file_period, scenario)[ts.label_indices]
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_inflow_period_lag!(
    inputs,
    ts::TimeSeriesView{T, N},
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    dimension_sizes = metadata_dimension_sizes(ts_metadata)
    for lag in 1:dimension_sizes[2], inflow_period in 1:dimension_sizes[1]
        ts.exact_dimensions_data[:, lag, inflow_period] =
            carrousel_read(ts.reader, ts_metadata; inflow_period, lag)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_inflow_period!(
    inputs,
    ts::TimeSeriesView{T, N},
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    for inflow_period in 1:metadata_dimension_sizes(ts_metadata)[1]
        ts.exact_dimensions_data[:, inflow_period] =
            carrousel_read(ts.reader, ts_metadata; inflow_period)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_season_sample_subscenario_subperiod!(
    inputs,
    ts::TimeSeriesView{T, N};
    season::Int,
    sample::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    dimension_sizes = metadata_dimension_sizes(ts_metadata)
    # Loop in subperiods
    for subperiod in 1:dimension_sizes[4],
        subscenario in 1:dimension_sizes[3]

        ts.exact_dimensions_data[:, subperiod, subscenario] =
            carrousel_read(ts.reader, ts_metadata; season, sample, subscenario, subperiod)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_season_sample_subperiod!(
    inputs,
    ts::TimeSeriesView{T, N};
    season::Int,
    sample::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    # Loop in subperiods
    for subperiod in 1:metadata_dimension_sizes(ts_metadata)[3]
        ts.exact_dimensions_data[:, subperiod] =
            carrousel_read(ts.reader, ts_metadata; season, sample, subperiod)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_season_sample_subscenario!(
    inputs,
    ts::TimeSeriesView{T, N};
    season::Int,
    sample::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    # Loop in subperiods
    for subscenario in 1:metadata_dimension_sizes(ts_metadata)[3]
        ts.exact_dimensions_data[:, subscenario] =
            carrousel_read(ts.reader, ts_metadata; season, sample, subscenario)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_period!(
    inputs,
    ts::TimeSeriesView{T, N},
    period::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    file_period = get_file_period_from_problem_period(
        inputs,
        period,
        Quiver.string_to_date_time(Quiver.Binary.get_initial_datetime(ts_metadata)),
    )
    ts.exact_dimensions_data = carrousel_read(ts.reader, ts_metadata; period = file_period)[ts.label_indices]
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_scenario_lag!(
    inputs,
    ts::TimeSeriesView{T, N},
    scenario::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    for lag in 1:metadata_dimension_sizes(ts_metadata)[2]
        ts.exact_dimensions_data[:, lag] = carrousel_read(ts.reader, ts_metadata; scenario, lag)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_sample_lag!(
    inputs,
    ts::TimeSeriesView{T, N},
    sample::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    for lag in 1:metadata_dimension_sizes(ts_metadata)[2]
        ts.exact_dimensions_data[:, lag] = carrousel_read(ts.reader, ts_metadata; sample, lag)[ts.label_indices]
    end
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_scenario!(
    inputs,
    ts::TimeSeriesView{T, N},
    scenario::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    ts.exact_dimensions_data = carrousel_read(ts.reader, ts_metadata; scenario)[ts.label_indices]
    ts.data = ts.exact_dimensions_data
    return nothing
end

function read_season_sample!(
    inputs,
    ts::TimeSeriesView{T, N};
    season::Int,
    sample::Int,
) where {T, N}
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)
    ts.exact_dimensions_data = carrousel_read(ts.reader, ts_metadata; season, sample)[ts.label_indices]
    ts.data = ts.exact_dimensions_data
    return nothing
end
