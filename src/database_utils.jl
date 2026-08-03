#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

# Quiver.read_vector_floats/read_vector_integers silently skip elements whose
# vector is empty (no rows in the group table), which misaligns every
# subsequent element's data. Read element-by-element via `_by_id` instead.
"""
    read_vector_floats(db::Quiver.Database, collection::String, attribute::String)

Read a vector attribute for every element of `collection`, indexed by `id`
(one entry per element, in `id` order).
"""
read_vector_floats(db::Quiver.Database, collection::String, attribute::String) =
    [Quiver.read_vector_floats_by_id(db, collection, attribute, id) for id in Quiver.read_element_ids(db, collection)]

"""
    read_set_floats(db::Quiver.Database, collection::String, attribute::String)

Read a set attribute for every element of `collection`, indexed by `id`
(one entry per element, in `id` order).
"""
read_set_floats(db::Quiver.Database, collection::String, attribute::String) =
    [Quiver.read_set_floats_by_id(db, collection, attribute, id) for id in Quiver.read_element_ids(db, collection)]

# Quiver's update_element!/delete_element!/upsert_time_series_row! are
# addressed by id, not label, so any label-addressed write goes through this
# lookup first.
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

# Quiver has no relation-name concept of its own, only raw column names; callers
# that set a relation need to build the column name themselves
"""
    fk_column_name(collection_to::String, relation_type::String)

Compute the FK column name for a relation: `lowercase(collection_to) * "_" *
relation_type`.
"""
fk_column_name(collection_to::String, relation_type::String) = lowercase(collection_to) * "_" * relation_type

# Quiver.upsert_time_series_row! does INSERT OR REPLACE: any column not
# passed in the call is reset to NULL rather than left alone. Read the row's
# current values first and fold in every already-non-null column so a
# single-attribute update doesn't wipe out the rest of the row.
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
