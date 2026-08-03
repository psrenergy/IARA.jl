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
    num_dc_lines = length(Quiver.read_element_ids(inputs.db, "DCLine"))
    if num_dc_lines == 0
        return nothing
    end

    dc_line.label = Quiver.read_scalar_strings(inputs.db, "DCLine", "label")
    dc_line.bus_to = Quiver.scalar_relation_map(inputs.db, "DCLine", "Bus", "to")
    dc_line.bus_from = Quiver.scalar_relation_map(inputs.db, "DCLine", "Bus", "from")

    update_time_series_from_db!(dc_line, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(dc_link::DCLine, db::Quiver.Database, period_date_time::DateTime)

Update the DC Line collection time series from the database.
"""
function update_time_series_from_db!(dc_line::DCLine, db::Quiver.Database, period_date_time::DateTime)
    date = Dates.format(period_date_time, "yyyymmddHHMMSS")
    dc_line.existing =
        @memoized_lru "dc_line-existing-$date" convert_to_enum.(
            Quiver.read_time_series_row(db, "DCLine", "parameters", "existing"; date_time = period_date_time),
            DCLine_Existence.T,
        )
    dc_line.capacity_to =
        @memoized_lru "dc_line-capacity_to-$date" Quiver.read_time_series_row(
            db, "DCLine", "parameters", "capacity_to"; date_time = period_date_time,
        )
    dc_line.capacity_from =
        @memoized_lru "dc_line-capacity_from-$date" Quiver.read_time_series_row(
            db, "DCLine", "parameters", "capacity_from"; date_time = period_date_time,
        )
    return nothing
end

"""
    add_dc_line!(db::Quiver.Database; kwargs...)

Add a DC Line to the database.

Required arguments:

  - `label::String`: Label of the DC line
  - `parameters::DataFrames.DataFrame: A dataframe containing time series attributes (described below).`

Optional arguments:

  - `bus_from::Int64`: Bus from of the DC line
  - `bus_to::Int64`: Bus to of the DC line

---

**Time Series Attributes**

Group `parameters`:

  - `date_time::Vector{DateTime}`: date and time of the time series
  - `existing::Vector{Int64}`: Existing of the DC line
    + `0` [Does Not Exist]
    + `1` [Exists]
  - `capacity_to::Vector{Float64}`: Capacity to of the DC line `[MW]`
  - `capacity_from::Vector{Float64}`: Capacity from of the DC line `[MW]`

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
function add_dc_line!(db::Quiver.Database; kwargs...)
    kwargs = Dict(kwargs...)
    parameters_df = pop!(kwargs, :parameters)

    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    id = Quiver.create_element!(db, "DCLine"; sql_typed_kwargs...)

    ts_kwargs = build_sql_typed_kwargs(parameters_df)
    Quiver.update_time_series_group!(db, "DCLine", "parameters", id; ts_kwargs...)
    return nothing
end

"""
    update_dc_line!(db::Quiver.Database, label::String; kwargs...)

Update the DC Line named 'label' in the database.
"""
function update_dc_line!(
    db::Quiver.Database,
    label::String;
    kwargs...,
)
    id = id_for_label(db, "DCLine", label)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    Quiver.update_element!(db, "DCLine", id; sql_typed_kwargs...)
    return db
end

"""
    update_dc_line_relation!(db::Quiver.Database, dc_line_label::String; collection::String, relation_type::String, related_label::String)

Update the DC Line named 'label' in the database.
"""
function update_dc_line_relation!(
    db::Quiver.Database,
    dc_line_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    id = id_for_label(db, "DCLine", dc_line_label)
    column = fk_column_name(collection, relation_type)
    Quiver.update_element!(db, "DCLine", id; Dict(Symbol(column) => related_label)...)
    return db
end

"""
    update_dc_line_time_series_parameter!(db::Quiver.Database, label::String, attribute::String, value; dimensions...)

Update a DC Line time series parameter in the database.
"""
function update_dc_line_time_series_parameter!(
    db::Quiver.Database,
    label::String,
    attribute::String,
    value;
    dimensions...,
)
    update_time_series_parameter!(
        db,
        "DCLine",
        "parameters",
        label,
        attribute,
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
