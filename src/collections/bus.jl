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
    Bus

Collection representing the buses in the system.
"""
@collection @kwdef mutable struct Bus <: AbstractCollection
    label::Vector{String} = []
    # index of the zone to which the bus belongs in the collection Zone
    zone_id_index::Vector{Int} = []
    latitude::Vector{Float64} = []
    longitude::Vector{Float64} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(bus::Bus, inputs::AbstractInputs)

Initialize the Bus collection from the database.
"""
function initialize!(bus::Bus, inputs::AbstractInputs)
    num_buses = PSRI.max_elements(inputs.db, "Bus")
    if num_buses == 0
        return nothing
    end

    bus.label = PSRI.get_parms(inputs.db, "Bus", "label")
    bus.zone_id_index = PSRI.get_map(inputs.db, "Bus", "Zone", "id")
    bus.latitude = PSRI.get_parms(inputs.db, "Bus", "latitude")
    bus.longitude = PSRI.get_parms(inputs.db, "Bus", "longitude")

    update_time_series_from_db!(bus, inputs.db, initial_date_time(inputs))

    return nothing
end

function update_time_series_from_db!(bus::Bus, db::DatabaseSQLite, period_date_time::DateTime)
    return nothing
end

"""
    add_bus!(db::DatabaseSQLite; kwargs...)

Add a bus to the database.

Required arguments:

  - `label::String`: Bus label

Optional arguments:

  - `zone_id::String`: Zone label (only if the zone is already in the database)

Example:
```julia
IARA.add_bus!(db;
    label = "bus_1",
    zone_id = "zone_1",
)
```
"""
function add_bus!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "Bus"; sql_typed_kwargs...)
    return nothing
end

"""
    update_bus!(db::DatabaseSQLite, label::String; kwargs...)

Update the Bus named 'label' in the database.
"""
function update_bus!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "Bus",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_bus_relation!(
        db::DatabaseSQLite,
        bus_label::String;
        collection::String,
        relation_type::String,
        related_label::String,
    )

Update the relation of the bus named `bus_label` with the collection `collection`.
"""
function update_bus_relation!(
    db::DatabaseSQLite,
    bus_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "Bus",
        collection,
        bus_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(bus::Bus)

Validate the bus collection.
"""
function validate(bus::Bus)
    return 0
end

"""
    advanced_validations(inputs::AbstractInputs, bus::Bus)

Validate the Bus within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, bus::Bus)
    num_errors = 0
    for i in 1:length(bus)
        if !(bus.zone_id_index[i] in index_of_elements(inputs, Zone))
            @error("Bus $(bus.label[i]) is not associated with any zone.")
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------
