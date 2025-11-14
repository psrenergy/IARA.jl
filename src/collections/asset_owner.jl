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
    AssetOwner

Collection representing the asset owners in the problem.
"""
@collection @kwdef mutable struct AssetOwner <: AbstractCollection
    label::Vector{String} = []
    price_type::Vector{AssetOwner_PriceType.T} = []
    purchase_discount_rate::Vector{Vector{Float64}} = []
    virtual_reservoir_energy_account_upper_bound::Vector{Vector{Float64}} = []
    risk_factor_for_virtual_reservoir_bids::Vector{Vector{Float64}} = []
    minimum_virtual_reservoir_purchase_bid_quantity_in_mw::Vector{Float64} = []
    # The convex revenue cache has information for a single asset owner at a time
    # Array dimensions are [bus, subperiod]
    # Vector dimension is the number of points in the convex hull
    # Point is a struct with (x, y) coordinates
    revenue_convex_hull::Array{Vector{Point}, 2} = Array{Vector{Point}, 2}(undef, 0, 0)
    _max_convex_hull_length::Array{Int, 2} = Array{Int, 2}(undef, 0, 0)
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(asset_owner::AssetOwner, inputs)

Initialize the AssetOwner collection from the database.
"""
function initialize!(asset_owner::AssetOwner, inputs::AbstractInputs)
    num_asset_owners = PSRI.max_elements(inputs.db, "AssetOwner")
    if num_asset_owners == 0
        return nothing
    end

    asset_owner.label = PSRI.get_parms(inputs.db, "AssetOwner", "label")
    asset_owner.price_type =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "AssetOwner", "price_type"),
            AssetOwner_PriceType.T,
        )
    asset_owner.minimum_virtual_reservoir_purchase_bid_quantity_in_mw =
        PSRI.get_parms(inputs.db, "AssetOwner", "minimum_virtual_reservoir_purchase_bid_quantity_in_mw")

    # Load vectors
    asset_owner.purchase_discount_rate = PSRI.get_vectors(inputs.db, "AssetOwner", "purchase_discount_rate")
    asset_owner.virtual_reservoir_energy_account_upper_bound =
        PSRI.get_vectors(inputs.db, "AssetOwner", "virtual_reservoir_energy_account_upper_bound")
    asset_owner.risk_factor_for_virtual_reservoir_bids =
        PSRI.get_vectors(inputs.db, "AssetOwner", "risk_factor_for_virtual_reservoir_bids")

    return nothing
end

"""
    add_asset_owner!(db::DatabaseSQLite; kwargs...)

Add an asset owner to the database.

$(PSRDatabaseSQLite.collection_docstring(model_directory(), "AssetOwner"))

Example:

```julia
IARA.add_asset_owner!(
    db;
    label = "AssetOwner1",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
```
"""
function add_asset_owner!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "AssetOwner"; sql_typed_kwargs...)
    return nothing
end

function delete_asset_owner!(db::DatabaseSQLite, label::String)
    PSRI.delete_element!(db, "AssetOwner", label)
    return nothing
end

"""
    update_asset_owner!(db::DatabaseSQLite, label::String; kwargs...)

Update the AssetOwner named 'label' in the database.

Example:
```julia
IARA.update_asset_owner!(
    db,
    "AssetOwner1";
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER
)
```
"""
function update_asset_owner!(db::DatabaseSQLite, label::String; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "AssetOwner",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

function update_asset_owner_vectors!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRDatabaseSQLite.update_vector_parameters!(
            db,
            "AssetOwner",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

function update_time_series_from_db!(asset_owner::AssetOwner, db::DatabaseSQLite, period_date_time::DateTime)
    return nothing
end

"""
    validate(asset_owner::AssetOwner)

Validate the asset owner collection.
"""
function validate(asset_owner::AssetOwner)
    num_errors = 0
    if count(asset_owner.price_type .== AssetOwner_PriceType.SUPPLY_SECURITY_AGENT) > 1
        num_errors += 1
        @error(
            "The number of supply security agents must be at most one, but found $(count(asset_owner.price_type .== AssetOwner_PriceType.SUPPLY_SECURITY_AGENT))."
        )
    end
    for i in 1:length(asset_owner)
        vector = asset_owner.virtual_reservoir_energy_account_upper_bound[i]
        if !isempty(vector)
            if !issorted(vector) || vector[end] != 1.0 || any(vector .< 0)
                num_errors += 1
                @error(
                    "Virtual reservoir energy account upper bound for asset owner $(asset_owner.label[i]) is not valid. " *
                    "It must be a sequence of increasing values ending with 1.0 and not containing negative values."
                )
            end
            if vector[1] == 0.0
                @warn(
                    "Virtual reservoir energy account upper bound for asset owner $(asset_owner.label[i]) starts with 0.0, which may not be intended for an upper bound."
                )
            end
        end
        for j in 1:length(asset_owner.purchase_discount_rate[i])
            if is_null(asset_owner.purchase_discount_rate[i][j])
                num_errors += 1
                @error(
                    "Purchase discount rate for asset owner $(asset_owner.label[i]) at index $j is null. " *
                    "This is not allowed."
                )
            elseif asset_owner.purchase_discount_rate[i][j] < 0.0
                num_errors += 1
                @error(
                    "Purchase discount rate for asset owner $(asset_owner.label[i]) at index $j is less than zero. " *
                    "This is not allowed."
                )
            end
        end
        if asset_owner.minimum_virtual_reservoir_purchase_bid_quantity_in_mw[i] < 0.0
            num_errors += 1
            @error(
                "Minimum virtual reservoir purchase bid quantity for asset owner $(asset_owner.label[i]) is less than zero. " *
                "This is not allowed."
            )
        end
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, asset_owner::AssetOwner)

Validate the AssetOwner within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, asset_owner::AssetOwner)
    num_errors = 0
    if generate_heuristic_bids_for_clearing(inputs) && use_virtual_reservoirs(inputs)
        all_virtual_reservoir_asset_owner_indices = union(virtual_reservoir_asset_owner_indices(inputs)...)

        # Check if any asset owner needs to set default risk factor and energy account upper bound
        has_missing_risk_factor = false
        for i in 1:length(asset_owner)
            if i in all_virtual_reservoir_asset_owner_indices
                if isempty(asset_owner.risk_factor_for_virtual_reservoir_bids[i])
                    has_missing_risk_factor = true
                    asset_owner.risk_factor_for_virtual_reservoir_bids[i] = [0.0]
                    asset_owner.virtual_reservoir_energy_account_upper_bound[i] = [1.0]
                end
                if length(asset_owner.purchase_discount_rate[i]) == 0
                    @error(
                        "Asset owner $(asset_owner.label[i]) has no purchase discount rate. This is required for virtual reservoir heuristic bids."
                    )
                    num_errors += 1
                end
            end
        end

        if has_missing_risk_factor
            @warn(
                "Some asset owners have no risk factor and energy account upper bound for virtual reservoir bids. " *
                "They will be set to zero and one, respectively, which may not be intended."
            )
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

is_current_asset_owner_price_taker(a::AssetOwner, i::Int) =
    if is_null(i)
        false
    else
        a.price_type[i] == AssetOwner_PriceType.PRICE_TAKER
    end
is_current_asset_owner_price_maker(a::AssetOwner, i::Int) =
    if is_null(i)
        false
    else
        a.price_type[i] == AssetOwner_PriceType.PRICE_MAKER
    end
is_current_asset_owner_supply_security_agent(a::AssetOwner, i::Int) =
    if is_null(i)
        false
    else
        a.price_type[i] == AssetOwner_PriceType.SUPPLY_SECURITY_AGENT
    end
is_current_asset_owner_price_taker(inputs::AbstractInputs, run_time_options::RunTimeOptions) =
    is_current_asset_owner_price_taker(inputs.collections.asset_owner, run_time_options.asset_owner_index)
is_current_asset_owner_price_maker(inputs::AbstractInputs, run_time_options::RunTimeOptions) =
    is_current_asset_owner_price_maker(inputs.collections.asset_owner, run_time_options.asset_owner_index)
is_current_asset_owner_supply_security_agent(inputs::AbstractInputs, run_time_options::RunTimeOptions) =
    is_current_asset_owner_supply_security_agent(inputs.collections.asset_owner, run_time_options.asset_owner_index)
is_current_asset_owner_bidder(inputs::AbstractInputs, run_time_options::RunTimeOptions) =
    is_current_asset_owner_price_taker(inputs, run_time_options) ||
    is_current_asset_owner_price_maker(inputs, run_time_options) ||
    is_current_asset_owner_supply_security_agent(inputs, run_time_options)
any_asset_owner_is_price_taker(inputs::AbstractInputs, run_time_options::RunTimeOptions) =
    any(
        is_current_asset_owner_price_taker(inputs.collections.asset_owner, i) for
        i in 1:length(inputs.collections.asset_owner)
    )
any_asset_owner_is_price_maker(inputs::AbstractInputs, run_time_options::RunTimeOptions) =
    any(
        is_current_asset_owner_price_maker(inputs.collections.asset_owner, i) for
        i in 1:length(inputs.collections.asset_owner)
    )
any_asset_owner_is_supply_security_agent(inputs::AbstractInputs, run_time_options::RunTimeOptions) =
    any(
        is_current_asset_owner_supply_security_agent(inputs.collections.asset_owner, i) for
        i in 1:length(inputs.collections.asset_owner)
    )

"""
    asset_owner_revenue_convex_hull_point(inputs::AbstractInputs, bus::Int, subperiod::Int, point_idx::Int)

Return a point in the revenue convex hull cache at a given bus and subperiod.
"""
function asset_owner_revenue_convex_hull_point(inputs::AbstractInputs, bus::Int, subperiod::Int, point_idx::Int)
    return inputs.collections.asset_owner.revenue_convex_hull[bus, subperiod][point_idx]
end

"""
    asset_owner_max_convex_hull_length(inputs::AbstractInputs, bus::Int, subperiod::Int)

Return the maximum number of points in the revenue convex hull cache at a given bus and subperiod.
"""
function asset_owner_max_convex_hull_length(inputs::AbstractInputs, bus::Int, subperiod::Int)
    return inputs.collections.asset_owner._max_convex_hull_length[bus, subperiod]
end

function asset_owner_minimum_virtual_reservoir_purchase_bid_quantity_in_mwh(
    inputs::AbstractInputs,
    ao::Int,
)
    hours_in_period = sum(subperiod_duration_in_hours(inputs, subperiod) for subperiod in subperiods(inputs))
    return hours_in_period * asset_owner_minimum_virtual_reservoir_purchase_bid_quantity_in_mw(inputs, ao)
end
