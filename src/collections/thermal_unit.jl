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
    ThermalUnit

Thermal units are high-level data structures that represent thermal electricity generation.
"""
@collection @kwdef mutable struct ThermalUnit <: AbstractCollection
    label::Vector{String} = []
    has_commitment::Vector{ThermalUnit_HasCommitment.T} = []
    existing::Vector{ThermalUnit_Existence.T} = []
    min_generation::Vector{Float64} = []
    max_generation::Vector{Float64} = []
    om_cost::Vector{Float64} = []
    max_ramp_up::Vector{Float64} = []
    max_ramp_down::Vector{Float64} = []
    min_uptime::Vector{Float64} = []
    max_uptime::Vector{Float64} = []
    min_downtime::Vector{Float64} = []
    max_startups::Vector{Int} = []
    max_shutdowns::Vector{Int} = []
    startup_cost::Vector{Float64} = []
    shutdown_cost::Vector{Float64} = []
    commitment_initial_condition::Vector{ThermalUnit_CommitmentInitialCondition.T} = []
    generation_initial_condition::Vector{Float64} = []
    uptime_initial_condition::Vector{Float64} = []
    downtime_initial_condition::Vector{Float64} = []
    # index of the bus to which the thermal unit belongs in the collection Bus
    bus_index::Vector{Int} = []
    # index of the bidding group to which the thermal unit belongs in the collection BiddingGroup
    bidding_group_index::Vector{Int} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(thermal_unit::ThermalUnit, inputs)

Initialize the Thermal Unit collection from the database.
"""
function initialize!(thermal_unit::ThermalUnit, inputs::AbstractInputs)
    num_thermal_units = PSRI.max_elements(inputs.db, "ThermalUnit")
    if num_thermal_units == 0
        return nothing
    end

    thermal_unit.label = PSRI.get_parms(inputs.db, "ThermalUnit", "label")
    thermal_unit.has_commitment =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "ThermalUnit", "has_commitment"),
            ThermalUnit_HasCommitment.T,
        )
    thermal_unit.max_ramp_up = PSRI.get_parms(inputs.db, "ThermalUnit", "max_ramp_up")
    thermal_unit.max_ramp_down = PSRI.get_parms(inputs.db, "ThermalUnit", "max_ramp_down")
    thermal_unit.min_uptime = PSRI.get_parms(inputs.db, "ThermalUnit", "min_uptime")
    thermal_unit.max_uptime = PSRI.get_parms(inputs.db, "ThermalUnit", "max_uptime")
    thermal_unit.min_downtime = PSRI.get_parms(inputs.db, "ThermalUnit", "min_downtime")
    thermal_unit.max_startups = PSRI.get_parms(inputs.db, "ThermalUnit", "max_startups")
    thermal_unit.max_shutdowns = PSRI.get_parms(inputs.db, "ThermalUnit", "max_shutdowns")
    thermal_unit.shutdown_cost = PSRI.get_parms(inputs.db, "ThermalUnit", "shutdown_cost")
    thermal_unit.commitment_initial_condition =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "ThermalUnit", "commitment_initial_condition"),
            ThermalUnit_CommitmentInitialCondition.T,
        )
    thermal_unit.generation_initial_condition =
        PSRI.get_parms(inputs.db, "ThermalUnit", "generation_initial_condition")
    thermal_unit.uptime_initial_condition =
        PSRI.get_parms(inputs.db, "ThermalUnit", "uptime_initial_condition")
    thermal_unit.downtime_initial_condition =
        PSRI.get_parms(inputs.db, "ThermalUnit", "downtime_initial_condition")
    thermal_unit.bus_index = PSRI.get_map(inputs.db, "ThermalUnit", "Bus", "id")
    thermal_unit.bidding_group_index = PSRI.get_map(inputs.db, "ThermalUnit", "BiddingGroup", "id")

    update_time_series_from_db!(thermal_unit, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(thermal_unit::ThermalUnit, db::DatabaseSQLite, period_date_time::DateTime)

Update the time series of the Thermal Unit collection from the database.
"""
function update_time_series_from_db!(
    thermal_unit::ThermalUnit,
    db::DatabaseSQLite,
    period_date_time::DateTime,
)
    date = Dates.format(period_date_time, "yyyymmddHHMMSS")
    thermal_unit.existing =
        @memoized_lru "thermal_unit-existing-$date" convert_to_enum.(
            PSRDatabaseSQLite.read_time_series_row(
                db,
                "ThermalUnit",
                "existing";
                date_time = period_date_time,
            ),
            ThermalUnit_Existence.T,
        )
    thermal_unit.min_generation =
        @memoized_lru "thermal_unit-min_generation-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "ThermalUnit",
            "min_generation";
            date_time = period_date_time,
        )
    thermal_unit.max_generation =
        @memoized_lru "thermal_unit-max_generation-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "ThermalUnit",
            "max_generation";
            date_time = period_date_time,
        )
    thermal_unit.om_cost =
        @memoized_lru "thermal_unit-om_cost-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "ThermalUnit",
            "om_cost";
            date_time = period_date_time,
        )
    thermal_unit.startup_cost =
        @memoized_lru "thermal_unit-startup_cost-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "ThermalUnit",
            "startup_cost";
            date_time = period_date_time,
        )
    return nothing
end

"""
    add_thermal_unit!(db::DatabaseSQLite; kwargs...)

Add a Thermal Unit to the database.

$(PSRDatabaseSQLite.collection_docstring(model_directory(), "ThermalUnit"))

!!! note "Note"
    - `biddinggroup_id` is required if `IARA.RunMode` is not set to `TRAIN_MIN_COST`.
    -  `min_generation` is ignored if `has_commitment` is set to `0`.

Example:
```julia
IARA.add_thermal_unit!(
    db;
    label = "Thermal1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [10.0],
    ),
    biddinggroup_id = "Thermal Owner",
    bus_id = "Island",
)
```
"""
function add_thermal_unit!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "ThermalUnit"; sql_typed_kwargs...)
    return nothing
end

"""
    update_thermal_unit!(db::DatabaseSQLite, label::String; kwargs...)

Update the Thermal Unit named 'label' in the database.
"""
function update_thermal_unit!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "ThermalUnit",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_thermal_unit_relation!(db::DatabaseSQLite, thermal_unit_label::String; collection::String, relation_type::String, related_label::String)

Update the Thermal Unit named 'label' in the database.
"""
function update_thermal_unit_relation!(
    db::DatabaseSQLite,
    thermal_unit_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "ThermalUnit",
        collection,
        thermal_unit_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    update_thermal_unit_time_series_parameter!(
        db::DatabaseSQLite, 
        label::String, 
        attribute::String, 
        value; 
        dimensions...
    )

Update a Thermal Unit time series parameter in the database for a given dimension value

Arguments:

  - `db::PSRClassesInterface.DatabaseSQLite`: Database
  - `label::String`: Thermal Unit label
  - `attribute::String`: Attribute name
  - `value`: Value to be updated
  - `dimensions...`: Dimension values

Example:
```julia
IARA.update_thermal_unit_time_series_parameter!(
    db,
    "therm_1",
    "om_cost",
    30.0;
    date_time = DateTime(0), # dimension value
)
```
"""
function update_thermal_unit_time_series_parameter!(
    db::DatabaseSQLite,
    label::String,
    attribute::String,
    value;
    dimensions...,
)
    PSRI.PSRDatabaseSQLite.update_time_series_row!(
        db,
        "ThermalUnit",
        attribute,
        label,
        value;
        dimensions...,
    )
    return db
end

"""
    validate(thermal_unit::ThermalUnit)

Validate the Thermal Units' parameters. Return the number of errors found.
"""
function validate(thermal_unit::ThermalUnit)
    num_errors = 0
    for i in 1:length(thermal_unit)
        if isempty(thermal_unit.label[i])
            @error("Thermal Unit Label cannot be empty.")
            num_errors += 1
        end
        if !is_null(thermal_unit.min_generation[i]) &&
           thermal_unit.min_generation[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Min Generation must be non-negative. Current value is $(thermal_unit.min_generation[i])."
            )
            num_errors += 1
        end
        if thermal_unit.max_generation[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Max Generation must be non-negative. Current value is $(thermal_unit.max_generation[i])."
            )
            num_errors += 1
        end
        if thermal_unit.om_cost[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) OM Cost must be non-negative. Current value is $(thermal_unit.om_cost[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.max_ramp_up[i]) && thermal_unit.max_ramp_up[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Max Ramp Up must be non-negative. Current value is $(thermal_unit.max_ramp_up[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.max_ramp_down[i]) &&
           thermal_unit.max_ramp_down[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Max Ramp Down must be non-negative. Current value is $(thermal_unit.max_ramp_down[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.min_uptime[i]) && thermal_unit.min_uptime[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Min Uptime must be non-negative. Current value is $(thermal_unit.min_uptime[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.max_uptime[i]) && thermal_unit.max_uptime[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Max Uptime must be non-negative. Current value is $(thermal_unit.max_uptime[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.min_downtime[i]) && thermal_unit.min_downtime[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Min Downtime must be non-negative. Current value is $(thermal_unit.min_downtime[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.max_startups[i]) && thermal_unit.max_startups[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Max Startups must be non-negative. Current value is $(thermal_unit.max_startups[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.max_shutdowns[i]) &&
           thermal_unit.max_shutdowns[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Max Shutdowns must be non-negative. Current value is $(thermal_unit.max_shutdowns[i])."
            )
            num_errors += 1
        end
        if thermal_unit.startup_cost[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Startup Cost must be non-negative. Current value is $(thermal_unit.startup_cost[i])."
            )
            num_errors += 1
        end
        if thermal_unit.shutdown_cost[i] < 0
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Shutdown Cost must be non-negative. Current value is $(thermal_unit.shutdown_cost[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.generation_initial_condition[i]) &&
           (
            thermal_unit.generation_initial_condition[i] < 0 ||
            thermal_unit.generation_initial_condition[i] > thermal_unit.max_generation[i]
        )
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Generation Initial Condition must be non-negative and less than or equal to Max Generation. Current values are $(thermal_unit.generation_initial_condition[i]) and $(thermal_unit.max_generation[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.uptime_initial_condition[i]) &&
           (
            thermal_unit.uptime_initial_condition[i] < 0 ||
            thermal_unit.uptime_initial_condition[i] > thermal_unit.max_uptime[i]
        )
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Uptime Initial Condition must be non-negative and less than or equal to Max Uptime. Current values are $(thermal_unit.uptime_initial_condition[i]) and $(thermal_unit.max_uptime[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.downtime_initial_condition[i]) &&
           (
            thermal_unit.downtime_initial_condition[i] < 0 ||
            thermal_unit.downtime_initial_condition[i] > thermal_unit.min_downtime[i]
        )
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Downtime Initial Condition must be non-negative and less than or equal to Min Downtime. Current values are $(thermal_unit.downtime_initial_condition[i]) and $(thermal_unit.min_downtime[i])."
            )
            num_errors += 1
        end
        if thermal_unit.min_generation[i] > thermal_unit.max_generation[i]
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Min Generation must be less than or equal to Max Generation. Current values are $(thermal_unit.min_generation[i]) and $(thermal_unit.max_generation[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.max_uptime[i]) &&
           thermal_unit.min_uptime[i] > thermal_unit.max_uptime[i]
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Min Uptime must be less than or equal to Max Uptime. Current values are $(thermal_unit.min_uptime[i]) and $(thermal_unit.max_uptime[i])."
            )
            num_errors += 1
        end
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, thermal_unit::ThermalUnit)

Validate the Thermal Unit within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, thermal_unit::ThermalUnit)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup)

    num_errors = 0
    for i in 1:length(thermal_unit)
        if !(thermal_unit.bus_index[i] in buses)
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Bus ID $(thermal_unit.bus_index[i]) not found."
            )
            num_errors += 1
        end
        if !is_null(thermal_unit.bidding_group_index[i]) &&
           !(thermal_unit.bidding_group_index[i] in bidding_groups)
            @error(
                "Thermal Unit $(thermal_unit.label[i]) Bidding Group ID $(thermal_unit.bidding_group_index[i]) not found."
            )
            num_errors += 1
        end
        if generate_heuristic_bids_for_clearing(inputs)
            if thermal_unit.has_commitment[i] == ThermalUnit_HasCommitment.HAS_COMMITMENT
                @warn(
                    "Heuristic bids for clearing are enabled. Commitment status of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if !is_null(thermal_unit.startup_cost[i]) && thermal_unit.startup_cost[i] > 0
                @warn(
                    "Heuristic bids for clearing are enabled. Startup cost of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if !is_null(thermal_unit.shutdown_cost[i]) && thermal_unit.shutdown_cost[i] > 0
                @warn(
                    "Heuristic bids for clearing are enabled. Shutdown cost of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if !is_null(thermal_unit.max_startups[i])
                @warn(
                    "Heuristic bids for clearing are enabled. Max Startups of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if !is_null(thermal_unit.max_shutdowns[i])
                @warn(
                    "Heuristic bids for clearing are enabled. Max Shutdowns of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if !is_null(thermal_unit.min_uptime[i])
                @warn(
                    "Heuristic bids for clearing are enabled. Min Uptime of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if !is_null(thermal_unit.min_downtime[i])
                @warn(
                    "Heuristic bids for clearing are enabled. Min Downtime of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if !is_null(thermal_unit.generation_initial_condition[i])
                @warn(
                    "Heuristic bids for clearing are enabled. Generation Initial Condition of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if !is_null(thermal_unit.uptime_initial_condition[i])
                @warn(
                    "Heuristic bids for clearing are enabled. Uptime Initial Condition of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if !is_null(thermal_unit.downtime_initial_condition[i])
                @warn(
                    "Heuristic bids for clearing are enabled. Downtime Initial Condition of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if thermal_unit_min_generation(inputs, i) > 0
                @warn(
                    "Heuristic bids for clearing are enabled. Min Generation of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if has_ramp_constraints(thermal_unit, i)
                @warn(
                    "Heuristic bids for clearing are enabled. Ramp constraints of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
            if has_commitment_initial_condition(thermal_unit, i)
                @warn(
                    "Heuristic bids for clearing are enabled. Commitment Initial Condition of Thermal Unit $(thermal_unit.label[i]) will not be reflected in the bidding bid."
                )
            end
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    thermal_unit_min_generation(inputs, idx::Int)

Return the min_generation of the Thermal Unit at index 'idx'.
"""
thermal_unit_min_generation(inputs::AbstractInputs, idx::Int) =
    is_null(inputs.collections.thermal_unit.min_generation[idx]) ? 0.0 :
    inputs.collections.thermal_unit.min_generation[idx]

"""
    has_commitment(thermal_unit::ThermalUnit, idx::Int)

Check if the Thermal Unit at index 'idx' has commitment.
"""
has_commitment(thermal_unit::ThermalUnit, idx::Int) =
    thermal_unit.has_commitment[idx] == ThermalUnit_HasCommitment.HAS_COMMITMENT

"""
    has_ramp_constraints(thermal_unit::ThermalUnit, idx::Int)

Check if the Thermal Unit at index 'idx' has ramp constraints.
"""
has_ramp_constraints(thermal_unit::ThermalUnit, idx::Int) =
    !is_null(thermal_unit.max_ramp_up[idx]) || !is_null(thermal_unit.max_ramp_down[idx])

"""
    has_commitment_initial_condition(thermal_unit::ThermalUnit, idx::Int)

Check if the Thermal Unit at index 'idx' has commitment initial condition.
"""
has_commitment_initial_condition(thermal_unit::ThermalUnit, idx::Int) =
    thermal_unit.commitment_initial_condition[idx] != ThermalUnit_CommitmentInitialCondition.UNDEFINED

function thermal_unit_zone_index(inputs::AbstractInputs, idx::Int)
    return bus_zone_index(inputs, thermal_unit_bus_index(inputs, idx))
end
