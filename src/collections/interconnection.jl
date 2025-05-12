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
    Interconnection

Collection representing the Interconnections in the system.
"""
@collection @kwdef mutable struct Interconnection <: AbstractCollection
    label::Vector{String} = []
    existing::Vector{Interconnection_Existence.T} = []
    capacity_to::Vector{Float64} = []
    capacity_from::Vector{Float64} = []
    # index of the Zone to in collection Zone
    zone_to::Vector{Int} = []
    # index of the Zone from in collection Zone
    zone_from::Vector{Int} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(interconnection::Interconnection, inputs::AbstractInputs)

Initialize the Interconnection collection from the database.
"""
function initialize!(interconnection::Interconnection, inputs::AbstractInputs)
    num_interconnections = PSRI.max_elements(inputs.db, "Interconnection")
    if num_interconnections == 0
        return nothing
    end

    interconnection.label = PSRI.get_parms(inputs.db, "Interconnection", "label")
    interconnection.zone_to = PSRI.get_map(inputs.db, "Interconnection", "Zone", "to")
    interconnection.zone_from = PSRI.get_map(inputs.db, "Interconnection", "Zone", "from")

    update_time_series_from_db!(interconnection, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(dc_link::Interconnection, db::DatabaseSQLite, period_date_time::DateTime)

Update the Interconnection collection time series from the database.
"""
function update_time_series_from_db!(interconnection::Interconnection, db::DatabaseSQLite, period_date_time::DateTime)
    date = Dates.format(period_date_time, "yyyymmddHHMMSS")
    interconnection.existing =
        @memoized_lru "interconnection-existing-$date" convert_to_enum.(
            PSRDatabaseSQLite.read_time_series_row(
                db,
                "Interconnection",
                "existing";
                date_time = period_date_time,
            ),
            Interconnection_Existence.T,
        )
    interconnection.capacity_to =
        @memoized_lru "interconnection-capacity_to-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "Interconnection",
            "capacity_to";
            date_time = period_date_time,
        )
    interconnection.capacity_from =
        @memoized_lru "interconnection-capacity_from-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "Interconnection",
            "capacity_from";
            date_time = period_date_time,
        )
    return nothing
end

"""
    add_interconnection!(db::DatabaseSQLite; kwargs...)

Add a Interconnection to the database.

$(PSRDatabaseSQLite.collection_docstring(model_directory(), "Interconnection"))

Example:
```julia
IARA.add_interconnection!(db;
    label = "dc_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.Interconnection_Existence.EXISTS)],
        capacity_to = [5.5],
        capacity_from = [5.5],
    ),
    zone_from = "Zone_1",
    zone_to = "Zone_2",
)
```
"""
function add_interconnection!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "Interconnection"; sql_typed_kwargs...)
    return nothing
end

"""
    update_interconnection!(db::DatabaseSQLite, label::String; kwargs...)

Update the Interconnection named 'label' in the database.
"""
function update_interconnection!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "Interconnection",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_interconnection_relation!(db::DatabaseSQLite, interconnection_label::String; collection::String, relation_type::String, related_label::String)

Update the Interconnection named 'label' in the database.
"""
function update_interconnection_relation!(
    db::DatabaseSQLite,
    interconnection_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "Interconnection",
        collection,
        interconnection_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    update_interconnection_time_series_parameter!(db::DatabaseSQLite, label::String, attribute::String, value; dimensions...)

Update a Interconnection time series parameter in the database.
"""
function update_interconnection_time_series_parameter!(
    db::DatabaseSQLite,
    label::String,
    attribute::String,
    value;
    dimensions...,
)
    PSRI.PSRDatabaseSQLite.update_time_series_row!(
        db,
        "Interconnection",
        attribute,
        label,
        value;
        dimensions...,
    )
    return db
end

"""
    validate(interconnection::Interconnection)

Validate the Interconnection collection.
"""
function validate(interconnection::Interconnection)
    num_errors = 0
    for i in 1:length(interconnection)
        if isempty(interconnection.label[i])
            @error("Interconnection Label cannot be empty.")
            num_errors += 1
        end
        if interconnection.capacity_to[i] < 0
            @error(
                "Interconnection $(interconnection.label[i]) Capacity To must be non-negative. Current value is $(interconnection.capacity_to[i])"
            )
            num_errors += 1
        end
        if interconnection.capacity_from[i] < 0
            @error(
                "Interconnection $(interconnection.label[i]) Capacity From must be non-negative. Current value is $(interconnection.capacity_from[i])"
            )
            num_errors += 1
        end
    end

    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, interconnection::Interconnection)

Validate the Interconnection within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, interconnection::Interconnection)
    Zonees = index_of_elements(inputs, Zone)

    num_errors = 0
    for i in 1:length(interconnection)
        if !(interconnection.zone_to[i] in Zonees)
            @error("Interconnection $(interconnection.label[i]) Zone To $(interconnection.zone_to[i]) not found.")
            num_errors += 1
        end
        if !(interconnection.zone_from[i] in Zonees)
            @error("Interconnection $(interconnection.label[i]) Zone From $(interconnection.zone_from[i]) not found.")
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------
