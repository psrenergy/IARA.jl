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
    ThermalPlant

Thermal plants are high-level data structures that represent thermal electricity generation.
"""
@collection @kwdef mutable struct ThermalPlant <: AbstractCollection
    label::Vector{String} = []
    has_commitment::Vector{ThermalPlant_HasCommitment.T} = []
    existing::Vector{ThermalPlant_Existence.T} = []
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
    commitment_initial_condition::Vector{ThermalPlant_CommitmentInitialCondition.T} = []
    generation_initial_condition::Vector{Float64} = []
    uptime_initial_condition::Vector{Float64} = []
    downtime_initial_condition::Vector{Float64} = []
    # index of the bus to which the thermal plant belongs in the collection Bus
    bus_index::Vector{Int} = []
    # index of the bidding group to which the thermal plant belongs in the collection BiddingGroup
    bidding_group_index::Vector{Int} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(thermal_plant::ThermalPlant, inputs)

Initialize the Thermal Plant collection from the database.
"""
function initialize!(thermal_plant::ThermalPlant, inputs::AbstractInputs)
    num_thermal_plants = PSRI.max_elements(inputs.db, "ThermalPlant")
    if num_thermal_plants == 0
        return nothing
    end

    thermal_plant.label = PSRI.get_parms(inputs.db, "ThermalPlant", "label")
    thermal_plant.has_commitment =
        PSRI.get_parms(inputs.db, "ThermalPlant", "has_commitment") .|> ThermalPlant_HasCommitment.T
    thermal_plant.max_ramp_up = PSRI.get_parms(inputs.db, "ThermalPlant", "max_ramp_up")
    thermal_plant.max_ramp_down = PSRI.get_parms(inputs.db, "ThermalPlant", "max_ramp_down")
    thermal_plant.min_uptime = PSRI.get_parms(inputs.db, "ThermalPlant", "min_uptime")
    thermal_plant.max_uptime = PSRI.get_parms(inputs.db, "ThermalPlant", "max_uptime")
    thermal_plant.min_downtime = PSRI.get_parms(inputs.db, "ThermalPlant", "min_downtime")
    thermal_plant.max_startups = PSRI.get_parms(inputs.db, "ThermalPlant", "max_startups")
    thermal_plant.max_shutdowns = PSRI.get_parms(inputs.db, "ThermalPlant", "max_shutdowns")
    thermal_plant.shutdown_cost = PSRI.get_parms(inputs.db, "ThermalPlant", "shutdown_cost")
    thermal_plant.commitment_initial_condition =
        PSRI.get_parms(inputs.db, "ThermalPlant", "commitment_initial_condition") .|>
        ThermalPlant_CommitmentInitialCondition.T
    thermal_plant.generation_initial_condition =
        PSRI.get_parms(inputs.db, "ThermalPlant", "generation_initial_condition")
    thermal_plant.uptime_initial_condition =
        PSRI.get_parms(inputs.db, "ThermalPlant", "uptime_initial_condition")
    thermal_plant.downtime_initial_condition =
        PSRI.get_parms(inputs.db, "ThermalPlant", "downtime_initial_condition")
    thermal_plant.bus_index = PSRI.get_map(inputs.db, "ThermalPlant", "Bus", "id")
    thermal_plant.bidding_group_index = PSRI.get_map(inputs.db, "ThermalPlant", "BiddingGroup", "id")

    update_time_series_from_db!(thermal_plant, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(thermal_plant::ThermalPlant, db::DatabaseSQLite, stage_date_time::DateTime)

Update the time series of the Thermal Plant collection from the database.
"""
function update_time_series_from_db!(
    thermal_plant::ThermalPlant,
    db::DatabaseSQLite,
    stage_date_time::DateTime,
)
    thermal_plant.existing =
        PSRDatabaseSQLite.read_time_series_row(
            db,
            "ThermalPlant",
            "existing";
            date_time = stage_date_time,
        ) .|> ThermalPlant_Existence.T
    thermal_plant.min_generation = PSRDatabaseSQLite.read_time_series_row(
        db,
        "ThermalPlant",
        "min_generation";
        date_time = stage_date_time,
    )
    thermal_plant.max_generation = PSRDatabaseSQLite.read_time_series_row(
        db,
        "ThermalPlant",
        "max_generation";
        date_time = stage_date_time,
    )
    thermal_plant.om_cost = PSRDatabaseSQLite.read_time_series_row(
        db,
        "ThermalPlant",
        "om_cost";
        date_time = stage_date_time,
    )
    thermal_plant.startup_cost = PSRDatabaseSQLite.read_time_series_row(
        db,
        "ThermalPlant",
        "startup_cost";
        date_time = stage_date_time,
    )

    return nothing
end

"""
    add_thermal_plant!(db::DatabaseSQLite; kwargs...)

Add a Thermal Plant to the database.

Required arguments:

  - `label::String`: label of the Thermal Plant.
  - `has_commitment::Int`: commitment status (0 -> false, 1 -> true)
    - _Default set to_ `0`
  - `shutdown_cost::Float64`: shutdown cost `[\$]`
    - _Default set to_ `0.0`
  - `bus_id::String`: Bus label for the thermal plant (only if the Bus already exists)
  - `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).
  - `biddinggroup_id::String`: Bidding Group label (only if the BiddingGroup already exists)
    - _Required if_ [`IARA.Configurations_RunMode`](@ref) _is not set to_ `CENTRALIZED_OPERATION`

    
Optional arguments:
  - `max_ramp_up::Float64`: maximum ramp up rate. `[MW/min]`
  - `max_ramp_down::Float64`: maximum ramp down rate. `[MW/min]`
  - `min_uptime::Float64`: minimum uptime `[hours]`
  - `max_uptime::Float64`: maximum uptime `[hours]`
  - `min_downtime::Float64`: minimum downtime `[hours]`
  - `max_startups::Int`: maximum startups
  - `max_shutdowns::Int`: maximum shutdowns
  - `commitment_initial_condition::Int`: Initial condition of the commitment of the thermal plant
  - `generation_initial_condition::Float64`: Initial condition of the generation of the thermal plant
  - `uptime_initial_condition::Float64`: Initial condition of the uptime of the thermal plant `[subperiods]`
  - `downtime_initial_condition::Float64`: Initial condition of the downtime of the thermal plant `[subperiods]`

---

**Time Series Parameters**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.

Required columns:
  - `date_time::Vector{DateTime}`: date and time of the time series data.
  - `existing::Vector{Int}`: existing status of the thermal plant (0 -> false, 1 -> true)
  - `max_generation::Vector{Float64}`: maximum generation `[MWh]`
  - `om_cost::Vector{Float64}`
  - `startup_cost::Vector{Float64}`: startup cost `[\$/MWh]`
    - _Mandatory if_ `has_commitment` _is set to_ `1`
  
Optional columns:
  - `min_generation::Vector{Float64}`: minimum generation `[MWh]`
    - _Ignored if_ `has_commitment` _is set to_ `0`
"""
function add_thermal_plant!(db::DatabaseSQLite; kwargs...)
    PSRI.create_element!(db, "ThermalPlant"; kwargs...)
    return nothing
end

"""
    update_thermal_plant!(db::DatabaseSQLite, label::String; kwargs...)

Update the Thermal Plant named 'label' in the database.
"""
function update_thermal_plant!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    for (attribute, value) in kwargs
        PSRI.set_parm!(
            db,
            "ThermalPlant",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_thermal_plant_relation!(db::DatabaseSQLite, thermal_plant_label::String; collection::String, relation_type::String, related_label::String)

Update the Thermal Plant named 'label' in the database.
"""
function update_thermal_plant_relation!(
    db::DatabaseSQLite,
    thermal_plant_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "ThermalPlant",
        collection,
        thermal_plant_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(thermal_plant::ThermalPlant)

Validate the Thermal Plants' parameters. Return the number of errors found.
"""
function validate(thermal_plant::ThermalPlant)
    num_errors = 0
    for i in 1:length(thermal_plant)
        if isempty(thermal_plant.label[i])
            @error("Thermal Plant Label cannot be empty.")
            num_errors += 1
        end
        if !is_null(thermal_plant.min_generation[i]) &&
           thermal_plant.min_generation[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Min Generation must be non-negative. Current value is $(thermal_plant.min_generation[i])."
            )
            num_errors += 1
        end
        if thermal_plant.max_generation[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Max Generation must be non-negative. Current value is $(thermal_plant.max_generation[i])."
            )
            num_errors += 1
        end
        if thermal_plant.om_cost[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) OM Cost must be non-negative. Current value is $(thermal_plant.om_cost[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.max_ramp_up[i]) && thermal_plant.max_ramp_up[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Max Ramp Up must be non-negative. Current value is $(thermal_plant.max_ramp_up[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.max_ramp_down[i]) &&
           thermal_plant.max_ramp_down[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Max Ramp Down must be non-negative. Current value is $(thermal_plant.max_ramp_down[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.min_uptime[i]) && thermal_plant.min_uptime[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Min Uptime must be non-negative. Current value is $(thermal_plant.min_uptime[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.max_uptime[i]) && thermal_plant.max_uptime[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Max Uptime must be non-negative. Current value is $(thermal_plant.max_uptime[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.min_downtime[i]) && thermal_plant.min_downtime[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Min Downtime must be non-negative. Current value is $(thermal_plant.min_downtime[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.max_startups[i]) && thermal_plant.max_startups[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Max Startups must be non-negative. Current value is $(thermal_plant.max_startups[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.max_shutdowns[i]) &&
           thermal_plant.max_shutdowns[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Max Shutdowns must be non-negative. Current value is $(thermal_plant.max_shutdowns[i])."
            )
            num_errors += 1
        end
        if thermal_plant.startup_cost[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Startup Cost must be non-negative. Current value is $(thermal_plant.startup_cost[i])."
            )
            num_errors += 1
        end
        if thermal_plant.shutdown_cost[i] < 0
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Shutdown Cost must be non-negative. Current value is $(thermal_plant.shutdown_cost[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.generation_initial_condition[i]) &&
           (
            thermal_plant.generation_initial_condition[i] < 0 ||
            thermal_plant.generation_initial_condition[i] > thermal_plant.max_generation[i]
        )
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Generation Initial Condition must be non-negative and less than or equal to Max Generation. Current values are $(thermal_plant.generation_initial_condition[i]) and $(thermal_plant.max_generation[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.uptime_initial_condition[i]) &&
           (
            thermal_plant.uptime_initial_condition[i] < 0 ||
            thermal_plant.uptime_initial_condition[i] > thermal_plant.max_uptime[i]
        )
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Uptime Initial Condition must be non-negative and less than or equal to Max Uptime. Current values are $(thermal_plant.uptime_initial_condition[i]) and $(thermal_plant.max_uptime[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.downtime_initial_condition[i]) &&
           (
            thermal_plant.downtime_initial_condition[i] < 0 ||
            thermal_plant.downtime_initial_condition[i] > thermal_plant.min_downtime[i]
        )
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Downtime Initial Condition must be non-negative and less than or equal to Min Downtime. Current values are $(thermal_plant.downtime_initial_condition[i]) and $(thermal_plant.min_downtime[i])."
            )
            num_errors += 1
        end
        if thermal_plant.min_generation[i] > thermal_plant.max_generation[i]
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Min Generation must be less than or equal to Max Generation. Current values are $(thermal_plant.min_generation[i]) and $(thermal_plant.max_generation[i])."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.max_uptime[i]) &&
           thermal_plant.min_uptime[i] > thermal_plant.max_uptime[i]
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Min Uptime must be less than or equal to Max Uptime. Current values are $(thermal_plant.min_uptime[i]) and $(thermal_plant.max_uptime[i])."
            )
            num_errors += 1
        end
    end
    return num_errors
end

"""
    validate_relations(inputs, thermal_plant::ThermalPlant)

Validate the references of the Thermal Plant collection. Return the number of errors found.
"""
function validate_relations(inputs::AbstractInputs, thermal_plant::ThermalPlant)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup)

    num_errors = 0
    for i in 1:length(thermal_plant)
        if !(thermal_plant.bus_index[i] in buses)
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Bus ID $(thermal_plant.bus_index[i]) not found."
            )
            num_errors += 1
        end
        if !is_null(thermal_plant.bidding_group_index[i]) &&
           !(thermal_plant.bidding_group_index[i] in bidding_groups)
            @error(
                "Thermal Plant $(thermal_plant.label[i]) Bidding Group ID $(thermal_plant.bidding_group_index[i]) not found."
            )
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    thermal_plant_min_generation(inputs, idx::Int)

Return the min_generation of the Thermal Plant at index 'idx'.
"""
thermal_plant_min_generation(inputs::AbstractInputs, idx::Int) =
    is_null(inputs.collections.thermal_plant.min_generation[idx]) ? 0.0 :
    inputs.collections.thermal_plant.min_generation[idx]

has_commitment(thermal_plant::ThermalPlant, idx::Int) =
    thermal_plant.has_commitment[idx] == ThermalPlant_HasCommitment.HAS_COMMITMENT

has_ramp_constraints(thermal_plant::ThermalPlant, idx::Int) =
    !is_null(thermal_plant.max_ramp_up[idx]) || !is_null(thermal_plant.max_ramp_down[idx])

has_commitment_initial_condition(thermal_plant::ThermalPlant, idx::Int) =
    thermal_plant.commitment_initial_condition[idx] != ThermalPlant_CommitmentInitialCondition.UNDEFINED
