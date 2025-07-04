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
    VirtualReservoirBidsView

Collection representing the virtual reservoirs' bids data read from external files in chunks.

Dimensions cached in virtual reservoir bid time series files are static:
- 1 - Virtual reservoir
- 2 - Asset owner
- 3 - Bid segment
"""
@kwdef mutable struct VirtualReservoirBidsView{T} <: ViewFromExternalFile
    reader::Union{Quiver.Reader{Quiver.binary}, Nothing} = nothing
    data::Array{T, 3} = Array{T, 3}(undef, 0, 0, 0)
end
function Base.getindex(time_series::VirtualReservoirBidsView{T}, inds...) where {T}
    return getindex(time_series.data, inds...)
end
function Base.size(time_series::VirtualReservoirBidsView{T}) where {T}
    return size(time_series.data)
end

function initialize_virtual_reservoir_bids_view_from_external_file!(
    ts::VirtualReservoirBidsView{T},
    inputs,
    file_path::AbstractString;
    expected_unit::String = "",
    possible_expected_dimensions::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}(),
    virtual_reservoirs_to_read::Vector{String} = String[],
    asset_owners_to_read::Vector{String} = String[],
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
    for vr in index_of_elements(inputs, VirtualReservoir)
        if virtual_reservoir_label(inputs, vr) in virtual_reservoirs_to_read
            for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
                if asset_owner_label(inputs, ao) in asset_owners_to_read
                    push!(labels_to_read, "$(virtual_reservoir_label(inputs, vr)) - $(asset_owner_label(inputs, ao))")
                end
            end
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
    dimension_size = ts.reader.metadata.dimension_size
    vr_bidding_segments = dimension_size[3]
    update_maximum_number_of_vr_bidding_segments!(inputs, vr_bidding_segments)

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

    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    asset_owners = index_of_elements(inputs, AssetOwner)
    number_of_bid_segments = maximum_number_of_vr_bidding_segments(inputs)

    ts.data = zeros(
        T,
        length(virtual_reservoirs),
        length(asset_owners),
        number_of_bid_segments,
    )

    # Initialize dynamic time series
    read_virtual_reservoir_bids_view_from_external_file!(
        inputs,
        ts;
        period = 1,
        scenario = 1,
    )

    return num_errors
end

function read_virtual_reservoir_bids_view_from_external_file!(
    inputs,
    ts::VirtualReservoirBidsView{T};
    period::Int,
    scenario::Int,
) where {T}
    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    for bs in 1:maximum_number_of_vr_bidding_segments(inputs)
        Quiver.goto!(ts.reader; period, scenario, bid_segment = bs)
        pair_index = 0
        # vr and ao are in a bad performance order, but it is convenient for maping pairs the correct way.
        for vr in virtual_reservoirs
            for ao in virtual_reservoir_asset_owner_indices(inputs, vr)
                pair_index += 1
                ts.data[vr, ao, bs] = ts.reader.data[pair_index]
            end
        end
        @assert pair_index == sum(length.(virtual_reservoir_asset_owner_indices(inputs)))
    end

    return nothing
end

function write_virtual_reservoir_bids_time_series_file(
    file_path::String,
    data::Array{T, 5};
    dimensions::Vector{String},
    labels_virtual_reservoirs::Vector{String},
    labels_asset_owners::Vector{String},
    virtual_reservoirs_to_asset_owners_map::Dict{String, Vector{String}},
    time_dimension::String,
    dimension_size::Vector{Int},
    initial_date::Union{String, DateTime} = "",
    unit::String = "",
    frequency::String = "month",
) where {T}

    # It expects to receive 5d arrays with the following dimensions:
    # 1 - virtual reservoir
    # 2 - asset owner
    # 3 - bid segment
    # 4 - scenario
    # 5 - period
    # Pairs of virtual reservoirs and asset owners that are not in the map should be filled with 0.0.
    # Pairs that are in the map should have positive values for at least one occurrence.

    num_virtual_reservoirs, num_asset_owners, num_bid_segments, num_scenarios, num_periods = size(data)
    @assert num_virtual_reservoirs == length(labels_virtual_reservoirs)
    @assert num_asset_owners == length(labels_asset_owners)
    number_of_pairs = 0
    for vr in 1:num_virtual_reservoirs
        if !haskey(virtual_reservoirs_to_asset_owners_map, labels_virtual_reservoirs[vr])
            @error("Virtual reservoir $(labels_virtual_reservoirs[vr]) is not in the map.")
        elseif isempty(virtual_reservoirs_to_asset_owners_map[labels_virtual_reservoirs[vr]])
            @error("Virtual reservoir $(labels_virtual_reservoirs[vr]) has no asset owners in the map.")
        end
        for ao in 1:num_asset_owners
            if labels_asset_owners[ao] in virtual_reservoirs_to_asset_owners_map[labels_virtual_reservoirs[vr]]
                number_of_pairs += 1
                if iszero(data[vr, ao, :, :, :])
                    @warn(
                        "Asset owner $(labels_asset_owners[ao]) is in the map for virtual reservoir $(labels_virtual_reservoirs[vr]), but the data is zero for all bid segment, scenario and period.",
                    )
                end
            else
                for bs in 1:num_bid_segments, scenario in 1:num_scenarios, period in 1:num_periods
                    if !iszero(data[vr, ao, bs, scenario, period])
                        @error(
                            "Asset owner $(labels_asset_owners[ao]) is not in the map for virtual reservoir $(labels_virtual_reservoirs[vr]), but the data is positive for bid segment $(bs), scenario $(scenario) and period $(period).",
                        )
                    end
                end
            end
        end
    end

    treated_array = zeros(T, number_of_pairs, num_bid_segments, num_scenarios, num_periods)
    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for bs in 1:num_bid_segments
                pair_index = 0
                # vr and ao are in a bad performance order, but it is convenient for maping pairs the correct way.
                for vr in 1:num_virtual_reservoirs
                    for ao in 1:num_asset_owners
                        if labels_asset_owners[ao] in
                           virtual_reservoirs_to_asset_owners_map[labels_virtual_reservoirs[vr]]
                            pair_index += 1
                            treated_array[pair_index, bs, scenario, period] =
                                data[vr, ao, bs, scenario, period]
                        end
                    end
                end
            end
        end
    end

    # It expects to receive 1d arrays with the following dimensions:
    treated_labels = String[]
    for vr_label in labels_virtual_reservoirs
        for ao_label in labels_asset_owners
            if ao_label in virtual_reservoirs_to_asset_owners_map[vr_label]
                label_for_pair = vr_label * " - " * ao_label
                push!(treated_labels, label_for_pair)
            end
        end
    end
    @assert length(treated_labels) == number_of_pairs

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
