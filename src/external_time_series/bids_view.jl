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
    BidsView

Collection representing the bids data read from external files in chunks.

Dimensions cached in bid time series files are static:
- 1 - Bidding group
- 2 - Bus
- 3 - Bid segment
- 4 - Subperiod
"""
@kwdef mutable struct BidsView{T} <: ViewFromExternalFile
    reader::Union{Quiver.Binary.File, Nothing} = nothing
    data::Array{T, 4} = Array{T, 4}(undef, 0, 0, 0, 0)
end
function Base.getindex(time_series::BidsView{T}, inds...) where {T}
    return getindex(time_series.data, inds...)
end
function Base.size(time_series::BidsView{T}) where {T}
    return size(time_series.data)
end
function Base.size(time_series::BidsView{T}, idx::Int) where {T}
    return size(time_series.data, idx)
end

function initialize_bids_view_from_external_file!(
    ts::BidsView{T},
    inputs,
    file_path::AbstractString;
    expected_unit::String = "",
    possible_expected_dimensions::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}(),
    bidding_groups_to_read::Vector{String} = String[],
    buses_to_read::Vector{String} = String[],
    has_profile_bids::Bool = false,
) where {T}
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

    labels_to_read = String[]
    for bg in bidding_groups_to_read
        for bus in buses_to_read
            push!(labels_to_read, "$bg - $bus")
        end
    end

    # Initialize time series
    ts.reader = Quiver.Binary.open_file(file_path; mode = 'r')
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)

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

    dimensions = metadata_dimension_names(ts_metadata)
    # Validate if the dimensions are as expected
    if !isempty(possible_expected_dimensions)
        # Iterate through all possible dimensions and check if the time series
        # is defined in one of them.
        dimension_is_valid = false
        for possible_dimensions in possible_expected_dimensions
            if dimensions == possible_dimensions
                dimension_is_valid = true
                break
            end
        end
        if !dimension_is_valid
            @error(
                "Time series file $(file_path) has dimensions $(dimensions). This is different from the possible dimensions of this file $possible_expected_dimensions.",
            )
            num_errors += 1
        end
    end

    # Allocate the array of correct size based on the dimension sizes of extra dimensions

    dimension_dict = get_dimension_dict_from_reader(ts.reader)

    if has_profile_bids
        bid_profiles = dimension_dict[:profile]
        segments_or_profile = 1:bid_profiles
        update_maximum_number_of_profiles!(inputs, bid_profiles)
    else
        bid_segments = dimension_dict[:bid_segment]
        segments_or_profile = 1:bid_segments
        update_maximum_number_of_bg_bidding_segments!(inputs, bid_segments)
    end

    all_bidding_groups = index_of_elements(inputs, BiddingGroup)
    buses = index_of_elements(inputs, Bus)
    blks = subperiods(inputs)

    ts.data = zeros(
        T,
        length(all_bidding_groups),
        length(buses),
        length(segments_or_profile),
        length(blks),
    )

    # Initialize dynamic time series
    read_bids_view_from_external_file!(
        inputs,
        ts;
        period = 1,
        scenario = 1,
        has_profile_bids,
    )

    return num_errors
end

function read_bids_view_from_external_file!(
    inputs,
    ts::BidsView{T};
    period::Int,
    scenario::Int,
    has_profile_bids::Bool = false,
) where {T}
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    buses = index_of_elements(inputs, Bus)

    blks = subperiods(inputs)
    num_buses = length(buses)
    ts_metadata = Quiver.Binary.get_metadata(ts.reader)

    for blk in blks
        # TODO: Generic form?
        if has_profile_bids
            for prf in 1:maximum_number_of_profiles(inputs)
                row = carrousel_read(ts.reader, ts_metadata; period, scenario, subperiod = blk, profile = prf)
                for (i, bg) in enumerate(bidding_groups), bus in buses
                    ts.data[bg, bus, prf, blk] = row[(i-1)*(num_buses)+bus]
                end
            end
        else
            for bds in 1:maximum_number_of_bg_bidding_segments(inputs)
                row = carrousel_read(ts.reader, ts_metadata; period, scenario, subperiod = blk, bid_segment = bds)
                for (i, bg) in enumerate(bidding_groups), bus in buses
                    ts.data[bg, bus, bds, blk] = row[(i-1)*(num_buses)+bus]
                end
            end
        end
    end

    return nothing
end

function write_bids_time_series_file(
    file_path::String,
    data::Array{T, 6};
    dimensions::Vector{String},
    labels_bidding_groups::Vector{String},
    labels_buses::Vector{String},
    time_dimension::String,
    dimension_size::Vector{Int},
    initial_date::Union{String, DateTime} = "",
    unit::String = "",
    frequency::String = "monthly",
) where {T}

    # It expects to receive 6d arrays with the following dimensions:
    # 1 - bidding group
    # 2 - bus
    # 3 - bid segment
    # 4 - subperiod
    # 5 - scenario
    # 6 - period
    num_bidding_groups, num_buses, num_bid_segments, num_subperiods, num_scenarios, num_periods = size(data)
    treated_array =
        zeros(T, num_bidding_groups * num_buses, num_bid_segments, num_subperiods, num_scenarios, num_periods)
    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for blk in 1:num_subperiods
                for bds in 1:num_bid_segments
                    for bus in 1:num_buses
                        for bg in 1:num_bidding_groups
                            treated_array[(bg-1)*(num_buses)+bus, bds, blk, scenario, period] =
                                data[bg, bus, bds, blk, scenario, period]
                        end
                    end
                end
            end
        end
    end

    # It expects to receive 1d arrays with the following dimensions:
    treated_labels = String[]
    for bg_label in labels_bidding_groups
        for bus_label in labels_buses
            label_for_pair = bg_label * " - " * bus_label
            push!(treated_labels, label_for_pair)
        end
    end

    array_to_binary_file(
        file_path,
        treated_array;
        dimensions,
        labels = treated_labels,
        time_dimension,
        dimension_size,
        initial_date,
        unit,
        frequency,
        digits = 6,
    )
    return nothing
end
