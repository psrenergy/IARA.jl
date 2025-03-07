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
    initial_storage::Vector{Float64} = []
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
    num_battery_units = PSRI.max_elements(inputs.db, "BatteryUnit")
    if num_battery_units == 0
        return nothing
    end

    battery_unit.label = PSRI.get_parms(inputs.db, "BatteryUnit", "label")
    battery_unit.initial_storage = PSRI.get_parms(inputs.db, "BatteryUnit", "initial_storage")
    battery_unit.bus_index = PSRI.get_map(inputs.db, "BatteryUnit", "Bus", "id")
    battery_unit.bidding_group_index = PSRI.get_map(inputs.db, "BatteryUnit", "BiddingGroup", "id")

    update_time_series_from_db!(battery_unit, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(battery_unit::BatteryUnit, db::DatabaseSQLite, period_date_time::DateTime)

Update the Battery Unit time series from the database.
"""
function update_time_series_from_db!(battery_unit::BatteryUnit, db::DatabaseSQLite, period_date_time::DateTime)
    date = Dates.format(period_date_time, "yyyymmddHHMMSS")
    battery_unit.existing =
        @memoized_serialization "battery-existing-$date" convert_to_enum.(
             PSRDatabaseSQLite.read_time_series_row(
                db,
                "BatteryUnit",
                "existing";
                date_time = period_date_time,
            ),
            BatteryUnit_Existence.T,
        )
    battery_unit.min_storage =
        @memoized_serialization "battery-min_storage-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "BatteryUnit",
            "min_storage";
            date_time = period_date_time,
        )
    battery_unit.max_storage =
        @memoized_serialization "battery-max_storage-$date"  PSRDatabaseSQLite.read_time_series_row(
            db,
            "BatteryUnit",
            "max_storage";
            date_time = period_date_time,
        )
    battery_unit.max_capacity =
        @memoized_serialization "battery-max_capacity-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "BatteryUnit",
            "max_capacity";
            date_time = period_date_time,
        )
    battery_unit.om_cost =
        @memoized_serialization "battery-om_cost-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "BatteryUnit",
            "om_cost";
            date_time = period_date_time,
        )
    return nothing
end

"""
    add_battery_unit!(db::DatabaseSQLite; kwargs...)

Add a Battery Unit to the database.

Required arguments:

- `label::String`: Battery Unit label
- `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).
- `bus_id::String`: Bus label (only if the bus is already in the database)
- `biddinggroup_id::String`: Bidding Group label (only if the BiddingGroup already exists)
  - _Required if_ [`IARA.RunMode`](@ref) _is not set to_ `TRAIN_MIN_COST`

Optional arguments:
- `initial_storage::Float64`: Initial storage `[MWh]`

--- 

**Time Series parameters**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.

Required columns:

  - `date_time::Vector{DateTime}`: date and time of the time series data.
  - `existing::Vector{Int}`: Whether the battery_unit is existing or not (0 -> not existing, 1 -> existing)
  - `min_storage::Vector{Float64}`: Minimum storage `[MWh]`
  - `max_storage::Vector{Float64}`: Maximum storage `[MWh]`
  - `max_capacity::Vector{Float64}`: Maximum capacity `[MWh]`
  - `om_cost::Vector{Float64}`: O&M cost `[\$/MWh]`

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
function add_battery_unit!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "BatteryUnit"; sql_typed_kwargs...)
    return nothing
end

"""
    update_battery_unit!(db::DatabaseSQLite, label::String; kwargs...)

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
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "BatteryUnit",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_battery_unit_relation!(db::DatabaseSQLite, battery_unit_label::String; collection::String, relation_type::String, related_label::String)

Update the Battery Unit named 'label' in the database.
"""
function update_battery_unit_relation!(
    db::DatabaseSQLite,
    battery_unit_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "BatteryUnit",
        collection,
        battery_unit_label,
        related_label,
        relation_type,
    )
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
        if battery_unit.initial_storage[i] < 0
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
        if !is_null(battery_unit.bidding_group_index[i]) && !(battery_unit.bidding_group_index[i] in bidding_groups)
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
