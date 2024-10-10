#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

export write_bids_time_series_file

""" 
    BidsView

Collection representing the bids data read from external files in chunks.

Dimensions cached in bid time series files are static:
- 1 - Bidding group
- 2 - Bus
- 3 - Bid segment
- 4 - Block
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

function initialize_bids_view_from_external_file!(
    ts::BidsView{T},
    inputs,
    file_path::AbstractString;
    expected_unit::String = "",
    bidding_groups_to_read::Vector{String} = String[],
    buses_to_read::Vector{String} = String[],
    has_multihour_bids::Bool = false,
) where {T}
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

    # Initialize dynamic time series
    ts.data = read_bids_view_from_external_file(
        inputs, ts.reader;
        stage = 1, scenario = 1, data_type = eltype(ts.data),
        has_multihour_bids,
    )

    return num_errors
end

function read_bids_view_from_external_file(
    inputs,
    reader::Quiver.Reader{Quiver.binary};
    stage::Int,
    scenario::Int,
    data_type::Type,
    has_multihour_bids::Bool = false,
)
    bidding_groups = index_of_elements(inputs, BiddingGroup)
    buses = index_of_elements(inputs, Bus)
    bid_segments = bidding_segments(inputs)
    segments_or_profile = bid_segments
    if has_multihour_bids
        bid_profiles = bidding_profiles(inputs)
        segments_or_profile = bid_profiles
    end
    blks = blocks(inputs)
    num_buses = length(buses)

    data = zeros(
        data_type,
        length(bidding_groups),
        length(buses),
        length(segments_or_profile),
        length(blks),
    )

    for blk in blks
        # TODO: Generic form?
        if has_multihour_bids
            for prf in bid_profiles
                Quiver.goto!(reader; stage, scenario, block = blk, profile = prf)
                for bg in bidding_groups, bus in buses
                    data[bg, bus, prf, blk] = reader.data[(bg-1)*(num_buses)+bus]
                end
            end
        else
            for bds in bid_segments
                Quiver.goto!(reader; stage, scenario, block = blk, bid_segment = bds)
                for bg in bidding_groups, bus in buses
                    data[bg, bus, bds, blk] = reader.data[(bg-1)*(num_buses)+bus]
                end
            end
        end
    end

    return data
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
) where {T}

    # It expects to receive 6d arrays with the following dimensions:
    # 1 - bidding group
    # 2 - bus
    # 3 - bid segment
    # 4 - block
    # 5 - scenario
    # 6 - stage
    num_bidding_groups, num_buses, num_bid_segments, num_blocks, num_scenarios, num_stages = size(data)
    treated_array = zeros(T, num_bidding_groups * num_buses, num_bid_segments, num_blocks, num_scenarios, num_stages)
    for stage in 1:num_stages
        for scenario in 1:num_scenarios
            for blk in 1:num_blocks
                for bds in 1:num_bid_segments
                    for bus in 1:num_buses
                        for bg in 1:num_bidding_groups
                            treated_array[(bg-1)*(num_buses)+bus, bds, blk, scenario, stage] =
                                data[bg, bus, bds, blk, scenario, stage]
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
        digits = 6,
    )
    return nothing
end
