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
    fill_nulls(values::AbstractVector, sentinel)

Replace every `nothing` entry in `values` with `sentinel`. Quiver's scalar reads
return `Vector{Optional{T}}` for nullable columns, while IARA's collection struct
fields are plain `Vector{T}` using IARA's own sentinel values (see `null_value`).
"""
fill_nulls(values::AbstractVector, sentinel) = something.(values, sentinel)

"""
    fill_no_relation(values::AbstractVector{Int64}, sentinel)

Replace every `-1` entry with `sentinel`. `-1` is `scalar_relation_map`'s
"no relation" convention, distinct from the `nothing` convention `fill_nulls`
handles for scalar reads.
"""
fill_no_relation(values::AbstractVector{Int64}, sentinel) = [v == -1 ? sentinel : v for v in values]

# Read wrappers (they exist because of differences on what should be a null to IARA vs. 
# what is null to Quiver) 

read_scalar_floats(db::Quiver.Database, collection::String, attribute::String) =
    fill_nulls(Quiver.read_scalar_floats(db, collection, attribute), null_value(Float64))
read_scalar_integers(db::Quiver.Database, collection::String, attribute::String) =
    fill_nulls(Quiver.read_scalar_integers(db, collection, attribute), null_value(Int))
read_scalar_strings(db::Quiver.Database, collection::String, attribute::String) =
    fill_nulls(Quiver.read_scalar_strings(db, collection, attribute), null_value(String))

# Quiver.read_vector_floats/read_vector_integers silently skip elements whose
# vector is empty (no rows in the group table), which misaligns every
# subsequent element's data. Read element-by-element via `_by_id` instead.
"""
    read_vector_floats(db::Quiver.Database, collection::String, attribute::String)
    read_vector_integers(db::Quiver.Database, collection::String, attribute::String)

Read a vector attribute for every element of `collection`, indexed by `id`
(one entry per element, in `id` order).
"""
read_vector_floats(db::Quiver.Database, collection::String, attribute::String) =
    [Quiver.read_vector_floats_by_id(db, collection, attribute, id) for id in Quiver.read_element_ids(db, collection)]
read_vector_integers(db::Quiver.Database, collection::String, attribute::String) =
    [Quiver.read_vector_integers_by_id(db, collection, attribute, id) for id in Quiver.read_element_ids(db, collection)]

# Quiver's "no relation" sentinel is -1; remap it to IARA's null_value(Int).
"""
    scalar_relation_map(db, collection_from, collection_to, relation_type)

Map each element of `collection_from` to the `id` of its related element in
`collection_to`, or `null_value(Int)` if unrelated.
"""
function scalar_relation_map(db::Quiver.Database, collection_from::String, collection_to::String, relation_type::String)
    return fill_no_relation(
        Quiver.scalar_relation_map(db, collection_from, collection_to, relation_type),
        null_value(Int),
    )
end

# Quiver's set_relation_map/read_set_integers_by_id classify group tables
# purely by literal `_set_`/`_vector_` substring in the table name, so they can
# never find a `_vector_`-named relation table — which is what every one of
# IARA's vector relations is.
#
# read_vector_floats_by_id/read_vector_integers_by_id also silently drop any
# individual row whose value is NULL — not just when an id has zero rows (the
# gap read_vector_floats/read_vector_integers above already fix), but any
# single NULL position within an otherwise-populated vector, shifting every
# later value in that vector left. Confirmed by direct raw-SQL comparison:
# a [1.0, NULL, 3.0] row-set for one id came back as [1.0, 3.0] (length 2), not
# length 3 with a sentinel at position 2. Quiver's metadata API has no way to
# recover the literal table name behind a vector group, so the fix below reads
# the table directly via parameterized SQL — the one deliberate exception, in
# this whole migration, to routing every read through Quiver's
# collection/attribute abstraction. Only use these for a vector column that is
# genuinely nullable in the schema; NOT NULL columns stay on the plain
# read_vector_floats/read_vector_integers wrappers above, which are already
# safe for them.

function vector_group_row_count(db::Quiver.Database, table::String, id::Int64)
    return something(Quiver.query_integer(db, "SELECT COUNT(*) FROM $table WHERE id = ?", [id]), 0)
end

"""
    read_vector_floats_preserving_nulls_by_id(db, table, attribute, id)
    read_vector_integers_preserving_nulls_by_id(db, table, attribute, id)

Read one element's vector attribute directly from its literal group `table`,
one row at a time, so a NULL entry maps to `null_value(...)` at its own
position instead of being dropped.
"""
function read_vector_floats_preserving_nulls_by_id(db::Quiver.Database, table::String, attribute::String, id::Int64)
    count = vector_group_row_count(db, table, id)
    return Float64[
        something(
            Quiver.query_float(db, "SELECT $attribute FROM $table WHERE id = ? AND vector_index = ?", [id, i]),
            null_value(Float64),
        )
        for i in 1:count
    ]
end
function read_vector_integers_preserving_nulls_by_id(db::Quiver.Database, table::String, attribute::String, id::Int64)
    count = vector_group_row_count(db, table, id)
    return Int64[
        something(
            Quiver.query_integer(db, "SELECT $attribute FROM $table WHERE id = ? AND vector_index = ?", [id, i]),
            null_value(Int),
        )
        for i in 1:count
    ]
end

"""
    read_vector_floats_preserving_nulls(db, collection, table, attribute)
    read_vector_integers_preserving_nulls(db, collection, table, attribute)

Like `read_vector_floats`/`read_vector_integers`, but for a vector column that
can itself contain NULL entries within an otherwise-populated row set. `table`
is the vector group's literal table name (e.g. `"BiddingGroup_vector_markup"`).
"""
function read_vector_floats_preserving_nulls(db::Quiver.Database, collection::String, table::String, attribute::String)
    return [
        read_vector_floats_preserving_nulls_by_id(db, table, attribute, id)
        for id in Quiver.read_element_ids(db, collection)
    ]
end
function read_vector_integers_preserving_nulls(
    db::Quiver.Database,
    collection::String,
    table::String,
    attribute::String,
)
    return [
        read_vector_integers_preserving_nulls_by_id(db, table, attribute, id)
        for id in Quiver.read_element_ids(db, collection)
    ]
end

"""
    vector_relation_map_preserving_nulls(db, collection_from, table, collection_to, relation_type)

Like a vector-relation counterpart of `scalar_relation_map`, but for a
vector-relation column that can itself contain NULL (unresolved) entries
within an otherwise-populated row set — see
`read_vector_integers_preserving_nulls`. Maps each element of
`collection_from` to the positions (within `collection_to`) of its related
elements, one `Vector{Int}` per element. Unresolved/null entries map to
`null_value(Int)`.
"""
function vector_relation_map_preserving_nulls(
    db::Quiver.Database,
    collection_from::String,
    table::String,
    collection_to::String,
    relation_type::String,
)
    column = fk_column_name(collection_to, relation_type)
    collection_to_ids = Quiver.read_element_ids(db, collection_to)
    return [
        [
            something(findfirst(==(related_id), collection_to_ids), null_value(Int))
            for related_id in related_ids
        ]
        for related_ids in read_vector_integers_preserving_nulls(db, collection_from, table, column)
    ]
end

# Quiver's update_element!/delete_element!/upsert_time_series_row! are addressed
# by id, not label, so any label-addressed write goes through this lookup first.
"""
    id_for_label(db::Quiver.Database, collection::String, label::String)

Resolve an element's `id` from its `label` within `collection`. Throws a
readable error if no element with `label` exists in `collection`.
"""
function id_for_label(db::Quiver.Database, collection::String, label::String)
    id = Quiver.query_integer(db, "SELECT id FROM $collection WHERE label = ?", [label])
    if id === nothing
        error("No element with label '$label' found in collection '$collection'.")
    end
    return id
end

# Quiver has no relation-name concept of its own, only raw column names;
# callers that set a relation need to build the column name themselves.
"""
    fk_column_name(collection_to::String, relation_type::String)

Compute the FK column name for a relation: `lowercase(collection_to) * "_" *
relation_type`.
"""
fk_column_name(collection_to::String, relation_type::String) = lowercase(collection_to) * "_" * relation_type

# Quiver.upsert_time_series_row! does INSERT OR REPLACE: any column not passed
# in the call is reset to NULL rather than left alone. Read the row's current
# values first and fold in every already-non-null column so a single-attribute
# update doesn't wipe out the rest of the row.
"""
    merged_time_series_row(db, collection, group, id, attribute, value; dimensions...)

Build the full kwargs `Dict` to pass to `Quiver.upsert_time_series_row!` for a
single-attribute update, preserving every other column's current value at that
row.
"""
function merged_time_series_row(
    db::Quiver.Database,
    collection::String,
    group::String,
    id::Int64,
    attribute::String,
    value;
    dimensions...,
)
    dim_name, dim_value = only(dimensions)
    row = Dict{Symbol, Any}(dim_name => dim_value)
    columns = Quiver.read_time_series_group(db, collection, group, id)
    dim_col = string(dim_name)
    if haskey(columns, dim_col)
        row_idx = findfirst(==(dim_value), columns[dim_col])
        if row_idx !== nothing
            for (col_name, col_values) in columns
                if col_name == dim_col || col_name == attribute
                    continue
                end
                existing = col_values[row_idx]
                if existing !== nothing
                    row[Symbol(col_name)] = existing
                end
            end
        end
    end
    row[Symbol(attribute)] = value
    return row
end

"""
    update_time_series_parameter!(db, collection, group, label, attribute, value; dimensions...)

Resolve `label` to an id, then upsert `attribute` at `dimensions` within
`group`, preserving the row's other current values.
"""
function update_time_series_parameter!(
    db::Quiver.Database,
    collection::String,
    group::String,
    label::String,
    attribute::String,
    value;
    dimensions...,
)
    id = id_for_label(db, collection, label)
    row = merged_time_series_row(db, collection, group, id, attribute, value; dimensions...)
    Quiver.upsert_time_series_row!(db, collection, group, id; row...)
    return db
end
