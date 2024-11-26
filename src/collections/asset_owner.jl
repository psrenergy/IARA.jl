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
    risk_factor::Vector{Vector{Float64}} = []
    segment_fraction::Vector{Vector{Float64}} = []
    # The convex revenue cache has information for a single asset owner at a time
    # Array dimensions are [bus, subperiod]
    # Vector dimension is the number of points in the convex hull
    # Point is a struct with (x, y) coordinates
    revenue_convex_hull::Array{Vector{Point}, 2} = Array{Vector{Point}, 2}(undef, 0, 0)
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

    # Load vectors
    asset_owner.risk_factor = PSRI.get_vectors(inputs.db, "AssetOwner", "risk_factor")
    asset_owner.segment_fraction = PSRI.get_vectors(inputs.db, "AssetOwner", "segment_fraction")

    # TODO: pass this to a post process, maybe fill_caches!
    # The reason is that it being empty is useful for advanced_validations 
    for i in 1:num_asset_owners
        if isempty(asset_owner.segment_fraction[i])
            asset_owner.segment_fraction[i] = [1.0]
        end
        if isempty(asset_owner.risk_factor[i])
            asset_owner.risk_factor[i] = [0.0]
        end
    end
    return nothing
end

"""
    add_asset_owner!(db::DatabaseSQLite; kwargs...)

Add an asset owner to the database.

Required arguments:

  - `label::String`: Asset owner label
  - `price_type::AssetOwner_PriceType.T`: Asset owner price type ([`AssetOwner_PriceType`](@ref))
    - _Default set to_ `AssetOwner_PriceType.PRICE_TAKER`
  - `risk_factor::Vector{Float64}`: risk factor of the asset owner.
  - `segment_fraction::Vector{Float64}`: fraction of the segment.
  
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

function update_time_series_from_db!(asset_owner::AssetOwner, db::DatabaseSQLite, period_date_time::DateTime)
    return nothing
end

"""
    validate(asset_owner::AssetOwner)

Validate the asset owner collection.
"""
function validate(asset_owner::AssetOwner)
    num_errors = 0
    for i in 1:length(asset_owner)
        if any(asset_owner.risk_factor[i] .< 0)
            @warn(
                "Asset owner $(asset_owner.label[i]) has negative risk factors $(asset_owner.risk_factor[i]). If this is intentional, ignore this warning."
            )
        end
        if all(is_null.(asset_owner.segment_fraction[i]))
            continue
        end
        if any(is_null.(asset_owner.segment_fraction[i]))
            @error("Segment fraction vector has both null and non-null values for Asset owner $(asset_owner.label[i]).")
        end
        if any(asset_owner.segment_fraction[i] .< 0)
            @error(
                "Segment fraction values must be non-negative. Asset owner $(asset_owner.label[i]) has segment fractions $(asset_owner.segment_fraction[i])."
            )
        end
        if sum(asset_owner.segment_fraction[i]) != 1.0
            @error(
                "Segment fractions must sum to 1. Asset owner $(asset_owner.label[i]) has segment fractions $(asset_owner.segment_fraction[i])."
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
    # TODO: Are these checks necessary for every run mode?
    all_virtual_reservoir_asset_owner_indices = hcat(
        [virtual_reservoir_asset_owner_indices(inputs, vr) for vr in index_of_elements(inputs, VirtualReservoir)]...,
    )
    for i in 1:length(asset_owner)
        # TODO: enable this after fixing the TODO in initialize!
        # if !(i in all_virtual_reservoir_asset_owner_indices) && !isempty(asset_owner.segment_fraction[i])
        #     @warn "Asset owner $(asset_owner.label[i]) is not associated to a virtual reservoir, but has segment fractions. The markup will be ignored."
        # end
        if i in all_virtual_reservoir_asset_owner_indices && isempty(asset_owner.segment_fraction[i])
            num_errors += 1
            @error(
                "Asset owner $(asset_owner.label[i]) is associated to a virtual reservoir, but has no segment fractions defined."
            )
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

is_price_taker(a::AssetOwner, i::Int) = a.price_type[i] == AssetOwner_PriceType.PRICE_TAKER
is_price_maker(a::AssetOwner, i::Int) = a.price_type[i] == AssetOwner_PriceType.PRICE_MAKER

"""
    asset_owner_revenue_convex_hull_point(inputs::AbstractInputs, bus::Int, subperiod::Int, point_idx::Int)

Return a point in the revenue convex hull cache at a given bus and subperiod.
"""
function asset_owner_revenue_convex_hull_point(inputs::AbstractInputs, bus::Int, subperiod::Int, point_idx::Int)
    return inputs.collections.asset_owner.revenue_convex_hull[bus, subperiod][point_idx]
end
