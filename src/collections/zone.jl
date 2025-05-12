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

@collection @kwdef mutable struct Zone <: AbstractCollection
    label::Vector{String} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(zone::Zone, inputs)

Initialize the Zone collection from the database.
"""
function initialize!(zone::Zone, inputs::AbstractInputs)
    num_zones = PSRI.max_elements(inputs.db, "Zone")
    if num_zones == 0
        return nothing
    end

    zone.label = PSRI.get_parms(inputs.db, "Zone", "label")

    return nothing
end

"""
    update_time_series_from_db!(zone::Zone, db::DatabaseSQLite, period_date_time::DateTime)

Update the Zone collection time series from the database.
"""
function update_time_series_from_db!(zone::Zone, db::DatabaseSQLite, period_date_time::DateTime)
    return nothing
end

"""
    add_zone!(db::DatabaseSQLite; kwargs...)

Add a zone to the database.

$(PSRDatabaseSQLite.collection_docstring(model_directory(), "Zone"))

Example:
```julia
IARA.add_zone!(db; label = "Island Zone")
```
"""
function add_zone!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "Zone"; sql_typed_kwargs...)
    return nothing
end

"""
    update_zone!(db::DatabaseSQLite, label::String; kwargs...)

Update the Zone named 'label' in the database.
"""
function update_zone!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "Zone",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    validate(zone::Zone)

Validate the zone collection.
"""
function validate(zone::Zone)
    num_errors = 0
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, zone::Zone)

Validate the Zone within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, zone::Zone)
    num_errors = 0
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------
