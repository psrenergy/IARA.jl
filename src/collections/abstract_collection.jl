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
    run_time_options::RunTimeOptions = RunTimeOptions(), @nospecialize(filters::Vector{<:Function} = Function[]),
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
    @nospecialize(filters::Vector{<:Function} = Function[])
)
    return length(index_of_elements(inputs, collection; run_time_options, filters))
end

function any_elements(
    inputs,
    collection::Type{<:AbstractCollection};
    run_time_options::RunTimeOptions = RunTimeOptions(),
    @nospecialize(filters::Vector{<:Function} = Function[])
)
    return !isempty(index_of_elements(inputs, collection; run_time_options, filters))
end

function is_existing(@nospecialize(c), i::Int)
    return Int(c.existing[i]) == 1
end

function iara_log(@nospecialize(collection::C)) where {C <: AbstractCollection}
    if length(collection) != 0
        Log.info("   $(nameof(C)): $(length(collection)) element(s)")
    end
end
