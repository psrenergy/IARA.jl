#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

export add_bidding_group!
export update_bidding_group!
export update_bidding_group_relation!

# ---------------------------------------------------------------------
# Collection definition
# ---------------------------------------------------------------------

"""
    BiddingGroup

Collection representing the bidding groups in the system.
"""
@collection @kwdef mutable struct BiddingGroup <: AbstractCollection
    label::Vector{String} = []
    bid_type::Vector{BiddingGroup_BidType.T} = []
    risk_factor::Vector{Vector{Float64}} = []
    segment_fraction::Vector{Vector{Float64}} = []
    simple_bid_max_segments::Vector{Int} = []
    multihour_bid_max_profiles::Vector{Int} = []
    # index of the asset_owner to which the bidding group belongs in the collection AssetOwner
    asset_owner_index::Vector{Int} = []
    quantity_offer_file::String = ""
    price_offer_file::String = ""
    quantity_offer_multihour_file::String = ""
    price_offer_multihour_file::String = ""
    parent_profile_multihour_file::String = ""
    complementary_grouping_multihour_file::String = ""
    minimum_activation_level_multihour_file::String = ""
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(bidding_group::BiddingGroup, inputs)

Initialize the BiddingGroup collection from the database.
"""
function initialize!(bidding_group::BiddingGroup, inputs::AbstractInputs)
    num_bidding_groups = PSRI.max_elements(inputs.db, "BiddingGroup")
    if num_bidding_groups == 0
        return nothing
    end

    bidding_group.label = PSRI.get_parms(inputs.db, "BiddingGroup", "label")
    bidding_group.bid_type = PSRI.get_parms(inputs.db, "BiddingGroup", "bid_type") .|> BiddingGroup_BidType.T
    bidding_group.asset_owner_index = PSRI.get_map(inputs.db, "BiddingGroup", "AssetOwner", "id")
    bidding_group.simple_bid_max_segments = PSRI.get_parms(inputs.db, "BiddingGroup", "simple_bid_max_segments")
    bidding_group.multihour_bid_max_profiles = PSRI.get_parms(inputs.db, "BiddingGroup", "multihour_bid_max_profiles")

    # Load vectors
    bidding_group.risk_factor = PSRI.get_vectors(inputs.db, "BiddingGroup", "risk_factor")
    bidding_group.segment_fraction = PSRI.get_vectors(inputs.db, "BiddingGroup", "segment_fraction")

    for i in 1:num_bidding_groups
        if isempty(bidding_group.segment_fraction[i])
            bidding_group.segment_fraction[i] = [1.0]
        end
        if isempty(bidding_group.risk_factor[i])
            bidding_group.risk_factor[i] = [0.0]
        end
    end

    # Load time series files
    bidding_group.quantity_offer_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "quantity_offer")
    bidding_group.price_offer_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "price_offer")
    bidding_group.quantity_offer_multihour_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "quantity_offer_multihour")
    bidding_group.price_offer_multihour_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "price_offer_multihour")
    bidding_group.parent_profile_multihour_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "parent_profile_multihour")
    bidding_group.complementary_grouping_multihour_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "complementary_grouping_multihour")
    bidding_group.minimum_activation_level_multihour_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "minimum_activation_level_multihour")

    update_time_series_from_db!(bidding_group, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(bidding_group::BiddingGroup, db::DatabaseSQLite, stage_date_time::DateTime)

Update the BiddingGroup time series from the database.
"""
function update_time_series_from_db!(bidding_group::BiddingGroup, db::DatabaseSQLite, stage_date_time::DateTime)
    return nothing
end

"""
    add_bidding_group!(db::DatabaseSQLite; kwargs...)

Add a BiddingGroup to the database.

Required arguments:

  - `label::String`: label of the Thermal Plant.
  - `bid_type::BiddingGroup_BidType.T`: [`IARA.BiddingGroup_BidType`](@ref) of the bidding group.
    - _Default_ is `BiddingGroup_BidType.MARKUP_HEURISTIC`
  - `simple_bid_max_segments::Int`: maximum number of segments for the simple bid.
    - _Default_ is `0`
  - `multihour_bid_max_profiles::Int`: maximum number of profiles for the multihour bid.
    - _Default_ is `0`
  - `assetowner_id::String`: Label of the AssetOwner to which the bidding group belongs (only if the AssetOwner is already in the database).
  - `risk_factor::Vector{Float64}`: risk factor of the bidding group.
  - `segment_fraction::Vector{Float64}`: fraction of the segment.	
"""
function add_bidding_group!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "BiddingGroup"; sql_typed_kwargs...)
    return nothing
end

"""
    update_bidding_group!(db::DatabaseSQLite, label::String; kwargs...)

Update the BiddingGroup named 'label' in the database.
"""
function update_bidding_group!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    for (attribute, value) in kwargs
        PSRI.set_parm!(
            db,
            "BiddingGroup",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_bidding_group_relation!(db::DatabaseSQLite, bidding_group_label::String; collection::String, relation_type::String, related_label::String)

Update the BiddingGroup named 'label' in the database.
"""
function update_bidding_group_relation!(
    db::DatabaseSQLite,
    bidding_group_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "BiddingGroup",
        collection,
        bidding_group_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(bidding_group::BiddingGroup)

Validate the BiddingGroup's parameters. Returns the number of errors found.
"""
function validate(bidding_group::BiddingGroup)
    num_errors = 0
    for i in 1:length(bidding_group)
        if isempty(bidding_group.label[i])
            @error("BiddingGroup Label cannot be empty.")
            num_errors += 1
        end
        if any(bidding_group.risk_factor[i] .< 0)
            @warn(
                "Bidding group $(bidding_group.label[i]) has negative risk factors $(bidding_group.risk_factor[i]). If this is intentional, ignore this warning."
            )
        end
        if all(is_null.(bidding_group.segment_fraction[i]))
            continue
        end
        if any(is_null.(bidding_group.segment_fraction[i]))
            @error "Segment fraction vector has both null and non-null values for Bidding group $(bidding_group.label[i])."
        end
        if any(bidding_group.segment_fraction[i] .< 0)
            @error "Segment fraction values must be non-negative. Bidding group $(bidding_group.label[i]) has segment fractions $(bidding_group.segment_fraction[i])."
        end
        if sum(bidding_group.segment_fraction[i]) != 1.0
            @error "Segment fractions must sum to 1. Bidding group $(bidding_group.label[i]) has segment fractions $(bidding_group.segment_fraction[i])."
        end
    end
    return num_errors
end

"""
    validate_relations(inputs, bidding_group::BiddingGroup)

Validate the BiddingGroup's references. Return the number of errors found.
"""
function validate_relations(inputs::AbstractInputs, bidding_group::BiddingGroup)
    asset_owners = index_of_elements(inputs, AssetOwner)
    num_errors = 0
    for i in 1:length(bidding_group)
        if !(bidding_group.asset_owner_index[i] in asset_owners)
            @error(
                "BiddingGroup $(bidding_group.label[i]) AssetOwner ID $(bidding_group.asset_owner_index[i]) not found."
            )
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

function maximum_multihour_profiles(inputs::AbstractInputs, idx)
    return inputs.collections.bidding_group.multihour_bid_max_profiles[idx]
end

function maximum_bid_segments(inputs::AbstractInputs, idx)
    if run_mode(inputs) == Configurations_RunMode.HEURISTIC_BID
        # TODO: implement this for the heuristic bid, use as part of bidding_segments(inputs)
        error(
            "To query the maximum number of segments in the HEURISTIC_BID run mode, use `length(bidding_segments(inputs))`.",
        )
    end
    if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING && generate_heuristic_bids_for_clearing(inputs)
        return length(bidding_segments(inputs))
    else
        return inputs.collections.bidding_group.simple_bid_max_segments[idx]
    end
end

markup_heuristic_bids(bg::BiddingGroup, i::Int) = bg.bid_type[i] == BiddingGroup_BidType.MARKUP_HEURISTIC
optimize_bids(bg::BiddingGroup, i::Int) = bg.bid_type[i] == BiddingGroup_BidType.OPTIMIZE
has_multihour_bids(bg::BiddingGroup, i::Int) = bg.multihour_bid_max_profiles[i] > 0
has_simple_bids(bg::BiddingGroup, i::Int) = bg.simple_bid_max_segments[i] > 0

index_among_multihour(inputs::AbstractInputs, idx::Int) =
    findfirst(isequal(idx), index_of_elements(inputs, BiddingGroup; filters = [has_multihour_bids]))

"""
maximum_bidding_segments(inputs)

Return the maximum number of bidding segments.
"""
maximum_number_of_bidding_segments(inputs::AbstractInputs) = bidding_segments(inputs)[end]

"""
    bidding_segments(inputs)

Return all bidding segments.
"""
function bidding_segments(inputs::AbstractInputs)
    if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING && read_bids_from_file(inputs)
        maximum_bid_segments_all_bgs =
            [maximum_bid_segments(inputs, bg) for bg in index_of_elements(inputs, BiddingGroup)]
        maximum_bid_segment = maximum(maximum_bid_segments_all_bgs)
        return collect(1:maximum_bid_segment)
    elseif run_mode(inputs) == Configurations_RunMode.HEURISTIC_BID ||
           (run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING && generate_heuristic_bids_for_clearing(inputs))
        # TODO We have the same code in bids.jl
        # This has to be rewritten into smaller functions and explained in the documentation
        # of the Guess bid idea
        bidding_group_indexes = index_of_elements(inputs, BiddingGroup; filters = [markup_heuristic_bids])
        hydro_plants = index_of_elements(inputs, HydroPlant; filters = [is_existing])
        thermal_plants = index_of_elements(inputs, ThermalPlant; filters = [is_existing])
        renewable_plants = index_of_elements(inputs, RenewablePlant; filters = [is_existing])

        number_of_bidding_groups = length(bidding_group_indexes)
        number_of_buses = number_of_elements(inputs, Bus)

        bidding_group_number_of_risk_factors = zeros(Int, number_of_bidding_groups)
        bidding_group_hydro_plants = [Int[] for _ in 1:number_of_bidding_groups]
        bidding_group_thermal_plants = [Int[] for _ in 1:number_of_bidding_groups]
        bidding_group_renewable_plants = [Int[] for _ in 1:number_of_bidding_groups]

        for bg in bidding_group_indexes
            bidding_group_number_of_risk_factors[bg] = length(bidding_group_risk_factor(inputs, bg))
            bidding_group_hydro_plants[bg] = findall(isequal(bg), hydro_plant_bidding_group_index(inputs))
            bidding_group_thermal_plants[bg] = findall(isequal(bg), thermal_plant_bidding_group_index(inputs))
            bidding_group_renewable_plants[bg] = findall(isequal(bg), renewable_plant_bidding_group_index(inputs))
        end

        number_of_hydro_plants_per_bidding_group_and_bus = zeros(Int, number_of_bidding_groups, number_of_buses)
        number_of_thermal_plants_per_bidding_group_and_bus = zeros(Int, number_of_bidding_groups, number_of_buses)
        number_of_renewable_plants_per_bidding_group_and_bus = zeros(Int, number_of_bidding_groups, number_of_buses)

        for bg in bidding_group_indexes
            for h in bidding_group_hydro_plants[bg]
                bus = hydro_plant_bus_index(inputs, h)
                number_of_hydro_plants_per_bidding_group_and_bus[bg, bus] += 1
            end
            for t in bidding_group_thermal_plants[bg]
                bus = thermal_plant_bus_index(inputs, t)
                number_of_thermal_plants_per_bidding_group_and_bus[bg, bus] += 1
            end
            for r in bidding_group_renewable_plants[bg]
                bus = renewable_plant_bus_index(inputs, r)
                number_of_renewable_plants_per_bidding_group_and_bus[bg, bus] += 1
            end
        end

        number_of_plants_per_bidding_group_and_bus =
            number_of_hydro_plants_per_bidding_group_and_bus .+
            number_of_thermal_plants_per_bidding_group_and_bus .+ number_of_renewable_plants_per_bidding_group_and_bus

        maximum_number_of_plants_per_bidding_group =
            dropdims(maximum(number_of_plants_per_bidding_group_and_bus; dims = 2); dims = 2)

        number_of_offer_segments = bidding_group_number_of_risk_factors .* maximum_number_of_plants_per_bidding_group
        maximum_number_of_offer_segments = maximum(number_of_offer_segments; init = 0)
        return collect(1:maximum_number_of_offer_segments)
    elseif run_mode(inputs) in [Configurations_RunMode.STRATEGIC_BID, Configurations_RunMode.PRICE_TAKER_BID]
        return [1]
    else
        error("Querying the `bidding_segments` does not make sense in Run mode $(run_mode(inputs)).")
    end
end

"""
    maximum_bidding_profiles(inputs)

Return the maximum number of bidding profiles.
"""
maximum_number_of_bidding_profiles(inputs::AbstractInputs) = bidding_profiles(inputs)[end]

"""
    bidding_profiles(inputs)

Return all bidding profiles.
"""
function bidding_profiles(inputs::AbstractInputs)
    if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING
        maximum_bid_profiles_all_bgs =
            [maximum_multihour_profiles(inputs, bg) for bg in index_of_elements(inputs, BiddingGroup)]
        maximum_bid_profile = maximum(maximum_bid_profiles_all_bgs)
        return collect(1:maximum_bid_profile)
    elseif run_mode(inputs) == Configurations_RunMode.HEURISTIC_BID
        error("Querying the `bidding_profiles` does not make sense in Run mode $(run_mode(inputs)).")
    elseif run_mode(inputs) in [Configurations_RunMode.STRATEGIC_BID, Configurations_RunMode.PRICE_TAKER_BID]
        return [1]
    else
        error("Querying the `bidding_profile` does not make sense in Run mode $(run_mode(inputs)).")
    end
end

function has_any_multihour_complex_input_files(inputs::AbstractInputs)
    return bidding_group_parent_profile_multihour_file(inputs) != "" &&
           bidding_group_complementary_grouping_multihour_file(inputs) != "" &&
           bidding_group_minimum_activation_level_multihour_file(inputs) != ""
end
