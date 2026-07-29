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
    num_interconnections = length(Quiver.read_element_ids(inputs.db, "Interconnection"))
    if num_interconnections == 0
        return nothing
    end

    interconnection.label = read_scalar_strings(inputs.db, "Interconnection", "label")
    interconnection.zone_to = scalar_relation_map(inputs.db, "Interconnection", "Zone", "to")
    interconnection.zone_from = scalar_relation_map(inputs.db, "Interconnection", "Zone", "from")

    update_time_series_from_db!(interconnection, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(dc_link::Interconnection, db::Quiver.Database, period_date_time::DateTime)

Update the Interconnection collection time series from the database.
"""
function update_time_series_from_db!(interconnection::Interconnection, db::Quiver.Database, period_date_time::DateTime)
    date = Dates.format(period_date_time, "yyyymmddHHMMSS")
    interconnection.existing =
        @memoized_lru "interconnection-existing-$date" convert_to_enum.(
            Quiver.read_time_series_row(db, "Interconnection", "parameters", "existing"; date_time = period_date_time),
            Interconnection_Existence.T,
        )
    interconnection.capacity_to =
        @memoized_lru "interconnection-capacity_to-$date" Quiver.read_time_series_row(
            db, "Interconnection", "parameters", "capacity_to"; date_time = period_date_time,
        )
    interconnection.capacity_from =
        @memoized_lru "interconnection-capacity_from-$date" Quiver.read_time_series_row(
            db, "Interconnection", "parameters", "capacity_from"; date_time = period_date_time,
        )
    return nothing
end

"""
    add_interconnection!(db::Quiver.Database; kwargs...)

Add a Interconnection to the database.

Required arguments:

  - `label::String`: Label of the interconnection
  - `parameters::DataFrames.DataFrame: A dataframe containing time series attributes (described below).`

Optional arguments:

  - `zone_from::Int64`: Zone from of the interconnection
  - `zone_to::Int64`: Zone to of the interconnection

---

**Time Series Attributes**

Group `parameters`:

  - `date_time::Vector{DateTime}`: date and time of the time series
  - `existing::Vector{Int64}`: Existing of the interconnection
    + `0` [Does Not Exist]
    + `1` [Exists]
  - `capacity_to::Vector{Float64}`: Capacity to of the interconnection `[MW]`
  - `capacity_from::Vector{Float64}`: Capacity from of the interconnection `[MW]`

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
function add_interconnection!(db::Quiver.Database; kwargs...)
    kwargs = Dict(kwargs...)
    parameters_df = pop!(kwargs, :parameters)

    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    id = Quiver.create_element!(db, "Interconnection"; sql_typed_kwargs...)

    ts_kwargs = build_sql_typed_kwargs(parameters_df)
    Quiver.update_time_series_group!(db, "Interconnection", "parameters", id; ts_kwargs...)
    return nothing
end

"""
    update_interconnection!(db::Quiver.Database, label::String; kwargs...)

Update the Interconnection named 'label' in the database.
"""
function update_interconnection!(
    db::Quiver.Database,
    label::String;
    kwargs...,
)
    id = id_for_label(db, "Interconnection", label)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    Quiver.update_element!(db, "Interconnection", id; sql_typed_kwargs...)
    return db
end

"""
    update_interconnection_relation!(db::Quiver.Database, interconnection_label::String; collection::String, relation_type::String, related_label::String)

Update the Interconnection named 'label' in the database.
"""
function update_interconnection_relation!(
    db::Quiver.Database,
    interconnection_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    id = id_for_label(db, "Interconnection", interconnection_label)
    column = fk_column_name(collection, relation_type)
    Quiver.update_element!(db, "Interconnection", id; Dict(Symbol(column) => related_label)...)
    return db
end

"""
    update_interconnection_time_series_parameter!(db::Quiver.Database, label::String, attribute::String, value; dimensions...)

Update a Interconnection time series parameter in the database.
"""
function update_interconnection_time_series_parameter!(
    db::Quiver.Database,
    label::String,
    attribute::String,
    value;
    dimensions...,
)
    update_time_series_parameter!(
        db,
        "Interconnection",
        "parameters",
        label,
        attribute,
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
