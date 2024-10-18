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
    Battery

Collection representing the batteries in the system.
"""
@collection @kwdef mutable struct Battery <: AbstractCollection
    label::Vector{String} = []
    existing::Vector{Battery_Existence.T} = []
    initial_storage::Vector{Float64} = []
    min_storage::Vector{Float64} = []
    max_storage::Vector{Float64} = []
    max_capacity::Vector{Float64} = []
    om_cost::Vector{Float64} = []
    # index of the bus to which the battery belongs in the collection Bus
    bus_index::Vector{Int} = []
    # index of the bidding_group to which the battery belongs in the collection BiddingGroup
    bidding_group_index::Vector{Int} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(battery::Battery, inputs)

Initialize the Battery collection from the database.
"""
function initialize!(battery::Battery, inputs::AbstractInputs)
    num_batteries = PSRI.max_elements(inputs.db, "Battery")
    if num_batteries == 0
        return nothing
    end

    battery.label = PSRI.get_parms(inputs.db, "Battery", "label")
    battery.initial_storage = PSRI.get_parms(inputs.db, "Battery", "initial_storage")
    battery.bus_index = PSRI.get_map(inputs.db, "Battery", "Bus", "id")
    battery.bidding_group_index = PSRI.get_map(inputs.db, "Battery", "BiddingGroup", "id")

    update_time_series_from_db!(battery, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(battery::Battery, db::DatabaseSQLite, stage_date_time::DateTime)

Update the Battery time series from the database.
"""
function update_time_series_from_db!(battery::Battery, db::DatabaseSQLite, stage_date_time::DateTime)
    battery.existing =
        PSRDatabaseSQLite.read_time_series_row(
            db,
            "Battery",
            "existing";
            date_time = stage_date_time,
        ) .|> Battery_Existence.T
    battery.min_storage = PSRDatabaseSQLite.read_time_series_row(
        db,
        "Battery",
        "min_storage";
        date_time = stage_date_time,
    )
    battery.max_storage = PSRDatabaseSQLite.read_time_series_row(
        db,
        "Battery",
        "max_storage";
        date_time = stage_date_time,
    )
    battery.max_capacity = PSRDatabaseSQLite.read_time_series_row(
        db,
        "Battery",
        "max_capacity";
        date_time = stage_date_time,
    )
    battery.om_cost = PSRDatabaseSQLite.read_time_series_row(
        db,
        "Battery",
        "om_cost";
        date_time = stage_date_time,
    )

    return nothing
end

"""
    add_battery!(db::DatabaseSQLite; kwargs...)

Add a Battery to the database.

Required arguments:

- `label::String`: Battery label
- `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).
- `bus_id::String`: Bus label (only if the bus is already in the database)
- `biddinggroup_id::String`: Bidding Group label (only if the BiddingGroup already exists)
  - _Required if_ [`IARA.Configurations_RunMode`](@ref) _is not set to_ `CENTRALIZED_OPERATION`

Optional arguments:
- `initial_storage::Float64`: Initial storage `[MWh]`

--- 

**Time Series parameters**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.

Required columns:

  - `date_time::Vector{DateTime}`: date and time of the time series data.
  - `existing::Vector{Int}`: Whether the battery is existing or not (0 -> not existing, 1 -> existing)
  - `min_storage::Vector{Float64}`: Minimum storage `[MWh]`
  - `max_storage::Vector{Float64}`: Maximum storage `[MWh]`
  - `max_capacity::Vector{Float64}`: Maximum capacity `[MWh]`
  - `om_cost::Vector{Float64}`: O&M cost `[\$/MWh]`

"""
function add_battery!(db::DatabaseSQLite; kwargs...)
    PSRI.create_element!(db, "Battery"; kwargs...)
    return nothing
end

"""
    update_battery!(db::DatabaseSQLite, label::String; kwargs...)

Update the Battery named 'label' in the database.
"""
function update_battery!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    for (attribute, value) in kwargs
        PSRI.set_parm!(
            db,
            "Battery",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_battery_relation!(db::DatabaseSQLite, battery_label::String; collection::String, relation_type::String, related_label::String)

Update the Battery named 'label' in the database.
"""
function update_battery_relation!(
    db::DatabaseSQLite,
    battery_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "Battery",
        collection,
        battery_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(battery::Battery)

Validate the Battery's parameters. Returns the number of errors found.
"""
function validate(battery::Battery)
    num_errors = 0
    for i in 1:length(battery)
        if isempty(battery.label[i])
            @error("Battery Label cannot be empty.")
            num_errors += 1
        end
        if battery.initial_storage[i] < 0
            @error(
                "Battery $(battery.label[i]) Initial Storage must be non-negative. Current value is $(battery.initial_storage[i])"
            )
            num_errors += 1
        end
        if battery.min_storage[i] < 0
            @error(
                "Battery $(battery.label[i]) Min Storage must be non-negative. Current value is $(battery.min_storage[i])"
            )
            num_errors += 1
        end
        if battery.max_storage[i] < 0
            @error(
                "Battery $(battery.label[i]) Max Storage must be non-negative. Current value is $(battery.max_storage[i])"
            )
            num_errors += 1
        end
        if battery.max_capacity[i] < 0
            @error(
                "Battery $(battery.label[i]) Max Capacity must be non-negative. Current value is $(battery.max_capacity[i])"
            )
            num_errors += 1
        end
        if battery.om_cost[i] < 0
            @error(
                "Battery $(battery.label[i]) OM Cost must be non-negative. Current value is $(battery.om_cost[i])"
            )
            num_errors += 1
        end
        if battery.min_storage[i] > battery.max_storage[i]
            @error(
                "Battery $(battery.label[i]) Min Storage must be less than or equal to Max Storage. Current values are $(battery.min_storage[i]) and $(battery.max_storage[i])."
            )
            num_errors += 1
        end
    end
    return num_errors
end

"""
    validate_relations(inputs, battery::Battery)

Validate the Battery's references. Return the number of errors found.
"""
function validate_relations(inputs::AbstractInputs, battery::Battery)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup)

    num_errors = 0
    for i in 1:length(battery)
        if !(battery.bus_index[i] in buses)
            @error("Battery $(battery.label[i]) Bus ID $(battery.bus_index[i]) not found.")
            num_errors += 1
        end
        if !is_null(battery.bidding_group_index[i]) && !(battery.bidding_group_index[i] in bidding_groups)
            @error("Battery $(battery.label[i]) Bidding Group ID $(battery.bidding_group_index[i]) not found.")
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------
