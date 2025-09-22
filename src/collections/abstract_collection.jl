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
    get_collection(inputs::Inputs, collection::Type{<:AbstractCollection})

Returns a `IARA.Collection` of the specified type from the inputs.

Example:

```julia
IARA.get_collection(inputs, IARA.BiddingGroup)
```
"""
function get_collection(inputs, collection::Type{<:AbstractCollection})
    for fieldname in fieldnames(Collections)
        c = getfield(inputs.collections, fieldname)
        if c isa collection
            return c
        end
    end
    return error("Collection $collection not found in inputs.")
end

function index_of_elements(
    inputs,
    collection::Type{<:AbstractCollection};
    run_time_options::RunTimeOptions = RunTimeOptions(),
    @nospecialize(filters::Vector{<:Function} = Function[]),
)
    c = get_collection(inputs, collection)
    element_indexes = Int[]
    if length(c) == 0
        return element_indexes
    end
    sizehint!(element_indexes, length(c))
    if is_null(run_time_options.asset_owner_index)
        for i in 1:length(c)
            should_include_element = true
            for f in filters
                if !f(c, i)
                    should_include_element = false
                    break
                end
            end
            if should_include_element
                push!(element_indexes, i)
            end
        end
        # When filtering by asset owner, the collection either is BiddingGroup, or is linked to a BiddingGroup via the bidding_group_index property
    elseif !hasproperty(c, :bidding_group_index) && !isa(c, BiddingGroup)
        error(
            "Collection $c does not have the property :bidding_group_index, but asset_owner_index is not null: $(run_time_options.asset_owner_index).",
        )
    else
        bidding_group_index = if isa(c, BiddingGroup)
            1:length(c)
        else
            c.bidding_group_index
        end
        for (i, bg_index) in enumerate(bidding_group_index)
            # Skip null/invalid bidding group indices to prevent BoundsError
            # when accessing bidding_group_asset_owner_index
            if isa(c, DemandUnit) && is_null(bg_index)
                continue
            end
            if bidding_group_asset_owner_index(inputs, bg_index) == run_time_options.asset_owner_index
                should_include_element = true
                for f in filters
                    if !f(c, i)
                        should_include_element = false
                        break
                    end
                end
                if should_include_element
                    push!(element_indexes, i)
                end
            end
        end
    end
    return element_indexes
end

function number_of_elements(
    inputs,
    collection::Type{<:AbstractCollection};
    run_time_options::RunTimeOptions = RunTimeOptions(),
    @nospecialize(filters::Vector{<:Function} = Function[]),
)
    return length(index_of_elements(inputs, collection; run_time_options, filters))
end

function any_elements(
    inputs,
    collection::Type{<:AbstractCollection};
    run_time_options::RunTimeOptions = RunTimeOptions(),
    @nospecialize(filters::Vector{<:Function} = Function[]),
)
    return !isempty(index_of_elements(inputs, collection; run_time_options, filters))
end

function is_existing(@nospecialize(c), i::Int)
    return Int(c.existing[i]) == 1
end

function has_no_bidding_group(@nospecialize(c), i::Int)
    return is_null(c.bidding_group_index[i])
end

function iara_log(@nospecialize(collection::C)) where {C <: AbstractCollection}
    if length(collection) != 0
        @info("   $(nameof(C)): $(length(collection)) element(s)")
    end
end

function index_of_elements_that_appear_at_some_point_in_study_horizon(
    inputs,
    collection::Type{<:AbstractCollection};
    run_time_options::RunTimeOptions = RunTimeOptions(),
    @nospecialize(filters::Vector{<:Function} = Function[]),
)
    # In order to initialize the outputs we have to take the filters at every period.
    # There could be a new hydro with minimum outflow that will only be considered in 
    # the study after a few years. This is the function to use to correctly 
    # initialize the outputs when we need any kind of filters.
    c = get_collection(inputs, collection)
    element_indexes = Int[]
    for period in 1:number_of_periods(inputs)
        period_date_time = date_time_from_period(inputs, period)
        # Update the collection at this point in time
        update_time_series_from_db!(c, inputs.db, period_date_time)
        idxs = index_of_elements(
            inputs,
            collection;
            run_time_options,
            filters,
        )
        for idx in idxs
            if idx in element_indexes
                continue
            end
            push!(element_indexes, idx)
        end
    end
    # Reset the collection to the first period
    period_date_time = date_time_from_period(inputs, 1)
    update_time_series_from_db!(c, inputs.db, period_date_time)
    sort!(element_indexes)
    return element_indexes
end
