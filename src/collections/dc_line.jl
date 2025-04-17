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
    DCLine

Collection representing the DC lines in the system.
"""
@collection @kwdef mutable struct DCLine <: AbstractCollection
    label::Vector{String} = []
    existing::Vector{DCLine_Existence.T} = []
    capacity_to::Vector{Float64} = []
    capacity_from::Vector{Float64} = []
    # index of the bus to in collection Bus
    bus_to::Vector{Int} = []
    # index of the bus from in collection Bus
    bus_from::Vector{Int} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(dc_line::DCLine, inputs::AbstractInputs)

Initialize the DC Line collection from the database.
"""
function initialize!(dc_line::DCLine, inputs::AbstractInputs)
    num_dc_lines = PSRI.max_elements(inputs.db, "DCLine")
    if num_dc_lines == 0
        return nothing
    end

    dc_line.label = PSRI.get_parms(inputs.db, "DCLine", "label")
    dc_line.bus_to = PSRI.get_map(inputs.db, "DCLine", "Bus", "to")
    dc_line.bus_from = PSRI.get_map(inputs.db, "DCLine", "Bus", "from")

    update_time_series_from_db!(dc_line, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(dc_link::DCLine, db::DatabaseSQLite, period_date_time::DateTime)

Update the DC Line collection time series from the database.
"""
function update_time_series_from_db!(dc_line::DCLine, db::DatabaseSQLite, period_date_time::DateTime)
    date = Dates.format(period_date_time, "yyyymmddHHMMSS")
    dc_line.existing =
        @memoized_lru "dc_line-existing-$date" convert_to_enum.(
            PSRDatabaseSQLite.read_time_series_row(
                db,
                "DCLine",
                "existing";
                date_time = period_date_time,
            ),
            DCLine_Existence.T,
        )
    dc_line.capacity_to =
        @memoized_lru "dc_line-capacity_to-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "DCLine",
            "capacity_to";
            date_time = period_date_time,
        )
    dc_line.capacity_from =
        @memoized_lru "dc_line-capacity_from-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "DCLine",
            "capacity_from";
            date_time = period_date_time,
        )
    return nothing
end

"""
    add_dc_line!(db::DatabaseSQLite; kwargs...)

Add a DC Line to the database.

$(PSRDatabaseSQLite.collection_docstring(model_directory(), "DCLine"))

Example:
```julia
IARA.add_dc_line!(db;
    label = "dc_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DCLine_Existence.EXISTS)],
        capacity_to = [5.5],
        capacity_from = [5.5],
    ),
    bus_from = "bus_1",
    bus_to = "bus_2",
)
```
"""
function add_dc_line!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "DCLine"; sql_typed_kwargs...)
    return nothing
end

"""
    update_dc_line!(db::DatabaseSQLite, label::String; kwargs...)

Update the DC Line named 'label' in the database.
"""
function update_dc_line!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "DCLine",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_dc_line_relation!(db::DatabaseSQLite, dc_line_label::String; collection::String, relation_type::String, related_label::String)

Update the DC Line named 'label' in the database.
"""
function update_dc_line_relation!(
    db::DatabaseSQLite,
    dc_line_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "DCLine",
        collection,
        dc_line_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    update_dc_line_time_series_parameter!(db::DatabaseSQLite, label::String, attribute::String, value; dimensions...)

Update a DC Line time series parameter in the database.
"""
function update_dc_line_time_series_parameter!(
    db::DatabaseSQLite,
    label::String,
    attribute::String,
    value;
    dimensions...,
)
    PSRI.PSRDatabaseSQLite.update_time_series_row!(
        db,
        "DCLine",
        attribute,
        label,
        value;
        dimensions...,
    )
    return db
end

"""
    validate(dc_line::DCLine)

Validate the DC Line collection.
"""
function validate(dc_line::DCLine)
    num_errors = 0
    for i in 1:length(dc_line)
        if isempty(dc_line.label[i])
            @error("DC Line Label cannot be empty.")
            num_errors += 1
        end
        if dc_line.capacity_to[i] < 0
            @error(
                "DC Line $(dc_line.label[i]) Capacity To must be non-negative. Current value is $(dc_line.capacity_to[i])"
            )
            num_errors += 1
        end
        if dc_line.capacity_from[i] < 0
            @error(
                "DC Line $(dc_line.label[i]) Capacity From must be non-negative. Current value is $(dc_line.capacity_from[i])"
            )
            num_errors += 1
        end
    end

    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, dc_line::DCLine)

Validate the DCLine within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, dc_line::DCLine)
    buses = index_of_elements(inputs, Bus)

    num_errors = 0
    for i in 1:length(dc_line)
        if !(dc_line.bus_to[i] in buses)
            @error("DC Line $(dc_line.label[i]) Bus To $(dc_line.bus_to[i]) not found.")
            num_errors += 1
        end
        if !(dc_line.bus_from[i] in buses)
            @error("DC Line $(dc_line.label[i]) Bus From $(dc_line.bus_from[i]) not found.")
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------
