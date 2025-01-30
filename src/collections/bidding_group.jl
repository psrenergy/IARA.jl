#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

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
    _bidding_group_max_segments_period::Vector{Int} = Int[]
    _bidding_group_max_profiles_period::Vector{Int} = Int[]
    _bidding_group_max_complementary_grouping_period::Vector{Int} = Int[]
    # index of the asset_owner to which the bidding group belongs in the collection AssetOwner
    asset_owner_index::Vector{Int} = []
    quantity_offer_file::String = ""
    price_offer_file::String = ""
    quantity_offer_profile_file::String = ""
    price_offer_profile_file::String = ""
    parent_profile_file::String = ""
    complementary_grouping_profile_file::String = ""
    minimum_activation_level_profile_file::String = ""
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(bidding_group::BiddingGroup, inputs::AbstractInputs)

Initialize the BiddingGroup collection from the database.
"""
function initialize!(bidding_group::BiddingGroup, inputs::AbstractInputs)
    num_bidding_groups = PSRI.max_elements(inputs.db, "BiddingGroup")
    if num_bidding_groups == 0
        return nothing
    end

    bidding_group.label = PSRI.get_parms(inputs.db, "BiddingGroup", "label")
    bidding_group.bid_type =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "BiddingGroup", "bid_type"),
            BiddingGroup_BidType.T,
        )
    bidding_group.asset_owner_index = PSRI.get_map(inputs.db, "BiddingGroup", "AssetOwner", "id")

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
    bidding_group.quantity_offer_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "quantity_offer_profile")
    bidding_group.price_offer_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "price_offer_profile")
    bidding_group.parent_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "parent_profile")
    bidding_group.complementary_grouping_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "complementary_grouping_profile")
    bidding_group.minimum_activation_level_profile_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "BiddingGroup", "minimum_activation_level_profile")

    update_time_series_from_db!(bidding_group, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(bidding_group::BiddingGroup, db::DatabaseSQLite, period_date_time::DateTime)

Update the BiddingGroup time series from the database.
"""
function update_time_series_from_db!(bidding_group::BiddingGroup, db::DatabaseSQLite, period_date_time::DateTime)
    return nothing
end

"""
    add_bidding_group!(db::DatabaseSQLite; kwargs...)

Add a BiddingGroup to the database.

Required arguments:

  - `label::String`: label of the Thermal Unit.
  - `bid_type::BiddingGroup_BidType.T`: [`IARA.BiddingGroup_BidType`](@ref) of the bidding group.
    - _Default_ is `BiddingGroup_BidType.MARKUP_HEURISTIC`
  - `assetowner_id::String`: Label of the AssetOwner to which the bidding group belongs (only if the AssetOwner is already in the database).
  - `risk_factor::Vector{Float64}`: risk factor of the bidding group.
  - `segment_fraction::Vector{Float64}`: fraction of the segment.	


Example:
```julia
IARA.add_bidding_group!(
    db;
    label = "bg_1",
    assetowner_id = "asset_owner_1",
    risk_factor = [0.5],
    segment_fraction = [1.0],
    independent_bid_max_segments = 2,
)
```	
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
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
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

Example:
```julia
IARA.update_bidding_group_relation!(
    db,
    "bg_1";
    collection = "AssetOwner",
    relation_type = "id",
    related_label = "asset_owner_2",
)
```
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
            @error(
                "Segment fraction vector has both null and non-null values for Bidding group $(bidding_group.label[i])."
            )
        end
        if any(bidding_group.segment_fraction[i] .< 0)
            @error(
                "Segment fraction values must be non-negative. Bidding group $(bidding_group.label[i]) has segment fractions $(bidding_group.segment_fraction[i])."
            )
        end
        if sum(bidding_group.segment_fraction[i]) != 1.0
            @error(
                "Segment fractions must sum to 1. Bidding group $(bidding_group.label[i]) has segment fractions $(bidding_group.segment_fraction[i])."
            )
        end
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, bidding_group::BiddingGroup)

Validate the BiddingGroup's context within the inputs. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, bidding_group::BiddingGroup)
    num_errors = 0

    # Check if the assigned AssetOwner exists in the database
    asset_owners = index_of_elements(inputs, AssetOwner)
    for i in 1:length(bidding_group)
        if !(bidding_group.asset_owner_index[i] in asset_owners)
            @error(
                "BiddingGroup $(bidding_group.label[i]) AssetOwner ID $(bidding_group.asset_owner_index[i]) not found."
            )
            num_errors += 1
        end
    end

    # Check if all bidding_groups have units assigned to them. If not, some run_modes and options are not available.
    thermal_units = index_of_elements(inputs, ThermalUnit)
    hydro_units = index_of_elements(inputs, HydroUnit)
    renewable_units = index_of_elements(inputs, RenewableUnit)
    battery_units = index_of_elements(inputs, BatteryUnit)
    number_of_units_per_bidding_group = zeros(Int, length(bidding_group))
    for t in thermal_units
        number_of_units_per_bidding_group[thermal_unit_bidding_group_index(inputs, t)] += 1
    end
    for h in hydro_units
        number_of_units_per_bidding_group[hydro_unit_bidding_group_index(inputs, h)] += 1
    end
    for r in renewable_units
        number_of_units_per_bidding_group[renewable_unit_bidding_group_index(inputs, r)] += 1
    end
    for b in battery_units
        number_of_units_per_bidding_group[battery_unit_bidding_group_index(inputs, b)] += 1
    end
    if any(number_of_units_per_bidding_group .== 0)
        if run_mode(inputs) == RunMode.SINGLE_PERIOD_HEURISTIC_BID
            @error(
                "Some bidding groups do not have any units assigned to them. This is not allowed for the SINGLE_PERIOD_HEURISTIC_BID run mode."
            )
            num_errors += 1
        end
        if is_market_clearing(inputs) && generate_heuristic_bids_for_clearing(inputs)
            @error(
                "Some bidding groups do not have any units assigned to them. This is not allowed when creating heuristic bids for the MARKET_CLEARING run mode."
            )
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

function update_number_of_bid_segments!(inputs::AbstractInputs, value::Int)
    value_array = fill(value, length(index_of_elements(inputs, BiddingGroup)))
    update_number_of_bid_segments!(inputs, value_array)
    return nothing
end

function update_number_of_bid_profiles!(inputs::AbstractInputs, value::Int)
    value_array = fill(value, length(index_of_elements(inputs, BiddingGroup)))
    update_number_of_bid_profiles!(inputs, value_array)
    return nothing
end

function update_number_of_complementary_grouping!(inputs::AbstractInputs, value::Int)
    value_array = fill(value, length(index_of_elements(inputs, BiddingGroup)))
    update_number_of_complementary_grouping!(inputs, value_array)
    return nothing
end

function update_number_of_bid_segments!(inputs::AbstractInputs, values::Array{Int})
    inputs.collections.bidding_group._bidding_group_max_segments_period = copy(values)
    return nothing
end

function update_number_of_bid_profiles!(inputs::AbstractInputs, values::Array{Int})
    inputs.collections.bidding_group._bidding_group_max_profiles_period = copy(values)
    return nothing
end

function update_number_of_complementary_grouping!(inputs::AbstractInputs, values::Array{Int})
    inputs.collections.bidding_group._bidding_group_max_complementary_grouping_period = copy(values)
    return nothing
end

"""
    markup_heuristic_bids(bg::BiddingGroup, i::Int)

Check if the bidding group at index 'i' has `IARA.BiddingGroup_BidType.MARKUP_HEURISTIC` bids.
"""
markup_heuristic_bids(bg::BiddingGroup, i::Int) = bg.bid_type[i] == BiddingGroup_BidType.MARKUP_HEURISTIC

"""
    optimize_bids(bg::BiddingGroup, i::Int)

Check if the bidding group at index 'i' has `IARA.BiddingGroup_BidType.OPTIMIZE` bids.
"""
optimize_bids(bg::BiddingGroup, i::Int) = bg.bid_type[i] == BiddingGroup_BidType.OPTIMIZE

"""
    maximum_bidding_segments(inputs)

Return the maximum number of bidding segments.
"""
maximum_number_of_bidding_segments(inputs::AbstractInputs) =
    maximum(inputs.collections.bidding_group._bidding_group_max_segments_period; init = 0)

"""
    maximum_bidding_profiles(inputs)

Return the maximum number of bidding profiles.
"""
maximum_number_of_bidding_profiles(inputs::AbstractInputs) =
    maximum(inputs.collections.bidding_group._bidding_group_max_profiles_period; init = 0)

"""
    maximum_complementary_grouping(inputs)

Return the maximum number of complementary grouping.
"""
maximum_number_of_complementary_grouping(inputs::AbstractInputs) =
    maximum(inputs.collections.bidding_group._bidding_group_max_complementary_grouping_period; init = 0)

"""
    bidding_profiles(inputs)

Return all bidding profiles.
"""
function bidding_profiles(inputs::AbstractInputs)
    if is_market_clearing(inputs)
        maximum_bid_profile = maximum_number_of_bidding_profiles(inputs)
        return collect(1:maximum_bid_profile)
    elseif run_mode(inputs) in [RunMode.STRATEGIC_BID, RunMode.PRICE_TAKER_BID]
        return [1]
    else
        error("Querying the `bidding_profile` does not make sense in Run mode $(run_mode(inputs)).")
    end
end

function bidding_segments(inputs::AbstractInputs)
    if is_market_clearing(inputs) || run_mode(inputs) == RunMode.SINGLE_PERIOD_HEURISTIC_BID
        maximum_bid_segment = maximum_number_of_bidding_segments(inputs)
        return collect(1:maximum_bid_segment)
    elseif run_mode(inputs) in [RunMode.STRATEGIC_BID, RunMode.PRICE_TAKER_BID]
        return [1]
    else
        error("Querying the `bidding_segment` does not make sense in Run mode $(run_mode(inputs)).")
    end
end

"""
    get_maximum_valid_segments(inputs::AbstractInputs)

Return the maximum number of bidding segments for each bidding group.
"""
function get_maximum_valid_segments(inputs::AbstractInputs)
    return inputs.collections.bidding_group._bidding_group_max_segments_period
end

"""
    get_maximum_valid_profiles(inputs::AbstractInputs)

Return the maximum number of bidding profiles for each bidding group.
"""
function get_maximum_valid_profiles(inputs::AbstractInputs)
    return inputs.collections.bidding_group._bidding_group_max_profiles_period
end

"""
    get_maximum_valid_complementary_grouping(inputs::AbstractInputs)

Return the maximum number of complementary grouping for each bidding group.
"""
function get_maximum_valid_complementary_grouping(inputs::AbstractInputs)
    return inputs.collections.bidding_group._bidding_group_max_complementary_grouping_period
end

function has_any_simple_bids(inputs::AbstractInputs)
    return maximum_number_of_bidding_segments(inputs) > 0
end

function has_any_profile_bids(inputs::AbstractInputs)
    return maximum_number_of_bidding_profiles(inputs) > 0
end

"""
    has_any_profile_complex_bids(inputs::AbstractInputs)
    
Return true if the bidding group has any profile complex input files.
"""
function has_any_profile_complex_bids(inputs::AbstractInputs)
    return has_any_profile_bids(inputs) &&
           (
        has_any_profile_complex_input_files(inputs) ||
        generate_heuristic_bids_for_clearing(inputs)
    )
end

function has_any_bid_simple_input_files(inputs::AbstractInputs)
    return bidding_group_quantity_offer_file(inputs) != "" && bidding_group_price_offer_file(inputs) != ""
end

function has_any_profile_input_files(inputs::AbstractInputs)
    return bidding_group_quantity_offer_profile_file(inputs) != "" &&
           bidding_group_price_offer_profile_file(inputs) != ""
end

"""
    has_any_profile_complex_input_files(inputs::AbstractInputs)
    
Return true if the bidding group has any profile complex input files.
"""
function has_any_profile_complex_input_files(inputs::AbstractInputs)
    return bidding_group_parent_profile_file(inputs) != "" &&
           bidding_group_complementary_grouping_profile_file(inputs) != "" &&
           bidding_group_minimum_activation_level_profile_file(inputs) != ""
end
