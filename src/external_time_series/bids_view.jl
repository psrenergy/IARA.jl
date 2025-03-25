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
    reader::Union{Quiver.Reader{Quiver.binary}, Nothing} = nothing
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
    file_path = if isfile(file_path * ".quiv")
        file_path
    else
        file_name = basename(file_path)
        file_dir = dirname(file_path)
        joinpath(file_dir, "temp", file_name)
    end

    labels_to_read = String[]
    for bg in bidding_groups_to_read
        for bus in buses_to_read
            push!(labels_to_read, "$bg - $bus")
        end
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

    dimensions = ts.reader.metadata.dimensions
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
        update_number_of_bid_profiles!(inputs, bid_profiles)
    else
        bid_segments = dimension_dict[:bid_segment]
        segments_or_profile = 1:bid_segments
        update_number_of_bid_segments!(inputs, bid_segments)
    end

    bidding_groups = index_of_elements(inputs, BiddingGroup)
    buses = index_of_elements(inputs, Bus)
    bid_segments = bidding_segments(inputs)
    segments_or_profile = bid_segments
    if has_profile_bids
        bid_profiles = bidding_profiles(inputs)
        segments_or_profile = bid_profiles
    end
    blks = subperiods(inputs)

    ts.data = zeros(
        T,
        length(bidding_groups),
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
    bidding_groups = index_of_elements(inputs, BiddingGroup)
    buses = index_of_elements(inputs, Bus)

    if has_profile_bids
        bid_profiles = bidding_profiles(inputs)
    else
        bid_segments = bidding_segments(inputs)
    end
    blks = subperiods(inputs)
    num_buses = length(buses)

    for blk in blks
        # TODO: Generic form?
        if has_profile_bids
            for prf in bid_profiles
                Quiver.goto!(ts.reader; period, scenario, subperiod = blk, profile = prf)
                for bg in bidding_groups, bus in buses
                    ts.data[bg, bus, prf, blk] = ts.reader.data[(bg-1)*(num_buses)+bus]
                end
            end
        else
            for bds in bid_segments
                Quiver.goto!(ts.reader; period, scenario, subperiod = blk, bid_segment = bds)
                for bg in bidding_groups, bus in buses
                    ts.data[bg, bus, bds, blk] = ts.reader.data[(bg-1)*(num_buses)+bus]
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
    frequency::String = "month",
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

    Quiver.array_to_file(
        file_path,
        treated_array,
        Quiver.csv; # TODO currently only writes in csv
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
