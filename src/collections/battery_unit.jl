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
    BatteryUnit

Collection representing the battery unit in the system.
"""
@collection @kwdef mutable struct BatteryUnit <: AbstractCollection
    label::Vector{String} = []
    existing::Vector{BatteryUnit_Existence.T} = []
    initial_storage::Vector{Union{Float64, Nothing}} = []
    min_storage::Vector{Float64} = []
    max_storage::Vector{Float64} = []
    max_capacity::Vector{Float64} = []
    om_cost::Vector{Float64} = []
    # index of the bus to which the battery_unit belongs in the collection Bus
    bus_index::Vector{Int} = []
    # index of the bidding_group to which the battery_unit belongs in the collection BiddingGroup
    bidding_group_index::Vector{Int} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(battery_unit::BatteryUnit, inputs::AbstractInputs)

Initialize the Battery Unit collection from the database.
"""
function initialize!(battery_unit::BatteryUnit, inputs::AbstractInputs)
    num_battery_units = length(Quiver.read_element_ids(inputs.db, "BatteryUnit"))
    if num_battery_units == 0
        return nothing
    end

    battery_unit.label = Quiver.read_scalar_strings(inputs.db, "BatteryUnit", "label")
    battery_unit.initial_storage = Quiver.read_scalar_floats(inputs.db, "BatteryUnit", "initial_storage")
    battery_unit.bus_index = Quiver.scalar_relation_map(inputs.db, "BatteryUnit", "Bus", "id")
    battery_unit.bidding_group_index = Quiver.scalar_relation_map(inputs.db, "BatteryUnit", "BiddingGroup", "id")

    update_time_series_from_db!(battery_unit, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(battery_unit::BatteryUnit, db::Quiver.Database, period_date_time::DateTime)

Update the Battery Unit time series from the database.
"""
function update_time_series_from_db!(
    battery_unit::BatteryUnit,
    db::Quiver.Database,
    period_date_time::DateTime,
)
    date = Dates.format(period_date_time, "yyyymmddHHMMSS")
    battery_unit.existing =
        @memoized_lru "battery_unit-existing-$date" convert_to_enum.(
            Quiver.read_time_series_row(db, "BatteryUnit", "parameters", "existing"; date_time = period_date_time),
            BatteryUnit_Existence.T,
        )
    battery_unit.min_storage =
        @memoized_lru "battery_unit-min_storage-$date" Quiver.read_time_series_row(
            db, "BatteryUnit", "parameters", "min_storage"; date_time = period_date_time,
        )
    battery_unit.max_storage =
        @memoized_lru "battery_unit-max_storage-$date" Quiver.read_time_series_row(
            db, "BatteryUnit", "parameters", "max_storage"; date_time = period_date_time,
        )
    battery_unit.max_capacity =
        @memoized_lru "battery_unit-max_capacity-$date" Quiver.read_time_series_row(
            db, "BatteryUnit", "parameters", "max_capacity"; date_time = period_date_time,
        )
    battery_unit.om_cost =
        @memoized_lru "battery_unit-om_cost-$date" Quiver.read_time_series_row(
            db, "BatteryUnit", "parameters", "om_cost"; date_time = period_date_time,
        )
    return nothing
end

"""
    add_battery_unit!(db::Quiver.Database; kwargs...)

Add a Battery Unit to the database.

Required arguments:

  - `label::String`: Label of the battery unit
  - `parameters::DataFrames.DataFrame: A dataframe containing time series attributes (described below).`

Optional arguments:

  - `initial_storage::Union{Float64, Nothing}`: Initial storage of the battery unit
  - `biddinggroup_id::Int64`: Bidding group of the battery unit
  - `bus_id::Int64`: Bus of the battery unit

---

**Time Series Attributes**

Group `parameters`:

  - `date_time::Vector{DateTime}`: date and time of the time series
  - `existing::Vector{Int64}`: Existing of the battery unit
    + `0` [Does Not Exist]
    + `1` [Exists]
  - `min_storage::Vector{Float64}`: Min storage of the battery unit
  - `max_storage::Vector{Float64}`: Max storage of the battery unit
  - `max_capacity::Vector{Float64}`: Max capacity of the battery unit
  - `om_cost::Vector{Float64}`: OM cost of the battery unit `[\$/MWh]`

!!! note "Note"
    - `biddinggroup_id` is ignored if the `IARA.RunMode` is set to `TRAIN_MIN_COST`.

Example:
```julia
IARA.add_battery_unit!(db;
    label = "bat_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.BatteryUnit_Existence.EXISTS)],
        min_storage = [0.0],
        max_storage = [10.0] * 1e3,
        max_capacity = [0.5],
        om_cost = [1.0],
    ),
    initial_storage = 0.0,
    bus_id = "bus_2",
)
```
"""
function add_battery_unit!(db::Quiver.Database; kwargs...)
    kwargs = Dict(kwargs...)
    parameters_df = pop!(kwargs, :parameters)

    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    id = Quiver.create_element!(db, "BatteryUnit"; sql_typed_kwargs...)

    ts_kwargs = build_sql_typed_kwargs(parameters_df)
    Quiver.update_time_series_group!(db, "BatteryUnit", "parameters", id; ts_kwargs...)
    return nothing
end

"""
    update_battery_unit!(db::Quiver.Database, label::String; kwargs...)

Update the Battery Unit named 'label' in the database.

Example:
```julia
IARA.update_battery_unit!(
    db,
    "BatteryUnit1";
    initial_storage = 0.0,
)
```
"""
function update_battery_unit!(
    db::Quiver.Database,
    label::String;
    kwargs...,
)
    id = id_for_label(db, "BatteryUnit", label)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    Quiver.update_element!(db, "BatteryUnit", id; sql_typed_kwargs...)
    return db
end

"""
    update_battery_unit_relation!(db::Quiver.Database, battery_unit_label::String; collection::String, relation_type::String, related_label::String)

Update the Battery Unit named 'label' in the database.
"""
function update_battery_unit_relation!(
    db::Quiver.Database,
    battery_unit_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    id = id_for_label(db, "BatteryUnit", battery_unit_label)
    column = fk_column_name(collection, relation_type)
    Quiver.update_element!(db, "BatteryUnit", id; Dict(Symbol(column) => related_label)...)
    return db
end

"""
    validate(battery_unit::BatteryUnit)

Validate the Battery's parameters. Returns the number of errors found.
"""
function validate(battery_unit::BatteryUnit)
    num_errors = 0
    for i in 1:length(battery_unit)
        if isempty(battery_unit.label[i])
            @error("Battery Label cannot be empty.")
            num_errors += 1
        end
        if isnothing(battery_unit.initial_storage[i])
            @error("Battery $(battery_unit.label[i]) Initial Storage must be defined.")
            num_errors += 1
        elseif battery_unit.initial_storage[i] < 0
            @error(
                "Battery $(battery_unit.label[i]) Initial Storage must be non-negative. Current value is $(battery_unit.initial_storage[i])"
            )
            num_errors += 1
        end
        if battery_unit.min_storage[i] < 0
            @error(
                "Battery $(battery_unit.label[i]) Min Storage must be non-negative. Current value is $(battery_unit.min_storage[i])"
            )
            num_errors += 1
        end
        if battery_unit.max_storage[i] < 0
            @error(
                "Battery $(battery_unit.label[i]) Max Storage must be non-negative. Current value is $(battery_unit.max_storage[i])"
            )
            num_errors += 1
        end
        if battery_unit.max_capacity[i] < 0
            @error(
                "Battery $(battery_unit.label[i]) Max Capacity must be non-negative. Current value is $(battery_unit.max_capacity[i])"
            )
            num_errors += 1
        end
        if battery_unit.om_cost[i] < 0
            @error(
                "Battery $(battery_unit.label[i]) OM Cost must be non-negative. Current value is $(battery_unit.om_cost[i])"
            )
            num_errors += 1
        end
        if battery_unit.min_storage[i] > battery_unit.max_storage[i]
            @error(
                "Battery $(battery_unit.label[i]) Min Storage must be less than or equal to Max Storage. Current values are $(battery_unit.min_storage[i]) and $(battery_unit.max_storage[i])."
            )
            num_errors += 1
        end
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, battery_unit::BatteryUnit)

Validate the Battery's context within the inputs. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, battery_unit::BatteryUnit)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup)

    num_errors = 0
    for i in 1:length(battery_unit)
        if !(battery_unit.bus_index[i] in buses)
            @error("Battery Unit $(battery_unit.label[i]) Bus ID $(battery_unit.bus_index[i]) not found.")
            num_errors += 1
        end
        if has_bidding_group(battery_unit, i) && !(battery_unit.bidding_group_index[i] in bidding_groups)
            @error(
                "Battery Unit $(battery_unit.label[i]) Bidding Group ID $(battery_unit.bidding_group_index[i]) not found."
            )
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

function battery_unit_zone_index(inputs::AbstractInputs, idx::Int)
    return bus_zone_index(inputs, battery_unit_bus_index(inputs, idx))
end
