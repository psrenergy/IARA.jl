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
    num_zones = length(Quiver.read_element_ids(inputs.db, "Zone"))
    if num_zones == 0
        return nothing
    end

    zone.label = read_scalar_strings(inputs.db, "Zone", "label")

    return nothing
end

"""
    update_time_series_from_db!(zone::Zone, db::Quiver.Database, period_date_time::DateTime)

Update the Zone collection time series from the database.
"""
function update_time_series_from_db!(zone::Zone, db::Quiver.Database, period_date_time::DateTime)
    return nothing
end

"""
    add_zone!(db::Quiver.Database; kwargs...)

Add a zone to the database.

Required arguments:

  - `label::String`: Label of the zone

Example:
```julia
IARA.add_zone!(db; label = "Island Zone")
```
"""
function add_zone!(db::Quiver.Database; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    Quiver.create_element!(db, "Zone"; sql_typed_kwargs...)
    return nothing
end

"""
    update_zone!(db::Quiver.Database, label::String; kwargs...)

Update the Zone named 'label' in the database.
"""
function update_zone!(
    db::Quiver.Database,
    label::String;
    kwargs...,
)
    id = id_for_label(db, "Zone", label)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    Quiver.update_element!(db, "Zone", id; sql_typed_kwargs...)
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
