#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

export add_renewable_plant!
export update_renewable_plant!
export update_renewable_plant_relation!
export update_renewable_plant_time_series!

# ---------------------------------------------------------------------
# Collection definition
# ---------------------------------------------------------------------

"""
    RenewablePlant

Renewable plants are high-level data structures that represent non-dispatchable electricity generation.
"""
@collection @kwdef mutable struct RenewablePlant <: AbstractCollection
    label::Vector{String} = []
    existing::Vector{Bool} = []
    max_generation::Vector{Float64} = []
    om_cost::Vector{Float64} = []
    curtailment_cost::Vector{Float64} = []
    technology_type::Vector{Int} = []
    # index of the bus to which the renewable plant belongs in the collection Bus
    bus_index::Vector{Int} = []
    # index of the bidding group to which the renewable plant belongs in the collection BiddingGroup
    bidding_group_index::Vector{Int} = []
    generation_file::String = ""
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(renewable_plant::RenewablePlant, inputs)

Initialize the Renewable Plant collection from the database.
"""
function initialize!(renewable_plant::RenewablePlant, inputs::AbstractInputs)
    num_renewable_plants = PSRI.max_elements(inputs.db, "RenewablePlant")
    if num_renewable_plants == 0
        return nothing
    end

    renewable_plant.label = PSRI.get_parms(inputs.db, "RenewablePlant", "label")
    renewable_plant.technology_type =
        PSRI.get_parms(inputs.db, "RenewablePlant", "technology_type")
    renewable_plant.bus_index = PSRI.get_map(inputs.db, "RenewablePlant", "Bus", "id")
    renewable_plant.bidding_group_index = PSRI.get_map(inputs.db, "RenewablePlant", "BiddingGroup", "id")

    # Load time series files
    renewable_plant.generation_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "RenewablePlant", "generation")

    update_time_series_from_db!(renewable_plant, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(renewable_plant::RenewablePlant, db::DatabaseSQLite, stage_date_time::DateTime)

Update the Renewable Plant collection time series from the database.
"""
function update_time_series_from_db!(
    renewable_plant::RenewablePlant,
    db::DatabaseSQLite,
    stage_date_time::DateTime,
)
    renewable_plant.existing = PSRDatabaseSQLite.read_time_series_row(
        db,
        "RenewablePlant",
        "existing";
        date_time = stage_date_time,
    )
    renewable_plant.max_generation = PSRDatabaseSQLite.read_time_series_row(
        db,
        "RenewablePlant",
        "max_generation";
        date_time = stage_date_time,
    )
    renewable_plant.om_cost = PSRDatabaseSQLite.read_time_series_row(
        db,
        "RenewablePlant",
        "om_cost";
        date_time = stage_date_time,
    )
    renewable_plant.curtailment_cost = PSRDatabaseSQLite.read_time_series_row(
        db,
        "RenewablePlant",
        "curtailment_cost";
        date_time = stage_date_time,
    )

    return nothing
end

"""
    add_renewable_plant!(db::DatabaseSQLite; kwargs...)

Add a Renewable Plant to the database.

Required arguments:
  - `label::String`: Renewable Plant label
  - `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).
  - `biddinggroup_id::String`: Bidding Group label (only if the BiddingGroup already exists)
    - _Required if_ [`IARA.Configurations_RunMode`](@ref) _is not set to_ `CENTRALIZED_OPERATION`
  - `bus_id::String`: Bus label (only if the bus is already in the database)

Optional arguments:
  - `technology_type::Int`: Renewable Plant technology type (0 -> Solar, 1 -> Wind)  

---

**Time Series**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.

Required columns:

  - `date_time::Vector{DateTime}`: date and time of the time series data.
  - `existing::Vector{Int}`: Whether the renewable plant is existing or not (0 -> not existing, 1 -> existing)
  - `max_generation::Vector{Float64}`: Maximum generation of the renewable plant. `[MWh]`
  - `om_cost::Vector{Float64}`: O&M cost of the renewable plant. `[\$/MWh]`
  - `curtailment_cost::Vector{Float64}`: Curtailment cost of the renewable plant. `[\$/MWh]`
"""
function add_renewable_plant!(db::DatabaseSQLite; kwargs...)
    PSRI.create_element!(db, "RenewablePlant"; kwargs...)
    return nothing
end

"""
    update_renewable_plant_time_series!(db::DatabaseSQLite, label::String; date_time::DateTime = DateTime(0), kwargs...)

Update time series attributes for the Renewable Plant named 'label' in the database.
"""

function update_renewable_plant_time_series!(
    db::DatabaseSQLite,
    label::String;
    date_time::DateTime = DateTime(0),
    kwargs...,
)
    for (attribute, value) in kwargs
        PSRDatabaseSQLite.update_time_series_row!(
            db,
            "RenewablePlant",
            string(attribute),
            label,
            value;
            date_time = date_time,
        )
    end
    return db
end

"""
    update_renewable_plant!(db::DatabaseSQLite, label::String; kwargs...)

Update the Renewable Plant named 'label' in the database.
"""
function update_renewable_plant!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    for (attribute, value) in kwargs
        PSRI.set_parm!(
            db,
            "RenewablePlant",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_renewable_plant_relation!(db::DatabaseSQLite, renewable_plant_label::String; collection::String, relation_type::String, related_label::String)

Update the Renewable Plant named 'label' in the database.
"""
function update_renewable_plant_relation!(
    db::DatabaseSQLite,
    renewable_plant_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "RenewablePlant",
        collection,
        renewable_plant_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(renewable_plant::RenewablePlant)

Validate the Renewable Plants' parameters. Return the number of errors found.
"""
function validate(renewable_plant::RenewablePlant)
    num_errors = 0
    for i in 1:length(renewable_plant)
        if isempty(renewable_plant.label[i])
            @error("Renewable Plant Label cannot be empty.")
            num_errors += 1
        end
        if renewable_plant.max_generation[i] < 0
            @error(
                "Renewable Plant $(renewable_plant.label[i]) Maximum generation must be non-negative. Current value is $(renewable_plant.max_generation[i])."
            )
            num_errors += 1
        end
        if renewable_plant.om_cost[i] < 0
            @error(
                "Renewable Plant $(renewable_plant.label[i]) O&M cost must be non-negative. Current value is $(renewable_plant.om_cost[i])."
            )
            num_errors += 1
        end
        if renewable_plant.curtailment_cost[i] < 0
            @error(
                "Renewable Plant $(renewable_plant.label[i]) Curtailment cost must be non-negative. Current value is $(renewable_plant.curtailment_cost[i])."
            )
            num_errors += 1
        end
    end
    return num_errors
end

"""
    validate_relations(inputs, renewable_plant::RenewablePlant)

Validate the Renewable Plants' references. Return the number of errors found.
"""
function validate_relations(inputs::AbstractInputs, renewable_plant::RenewablePlant)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup)

    num_errors = 0
    for i in 1:length(renewable_plant)
        if !(renewable_plant.bus_index[i] in buses)
            @error(
                "Renewable Plant $(renewable_plant.label[i]) Bus ID $(renewable_plant.bus_index[i]) not found."
            )
            num_errors += 1
        end
        if !is_null(renewable_plant.bidding_group_index[i]) &&
           !(renewable_plant.bidding_group_index[i] in bidding_groups)
            @error(
                "Renewable Plant $(renewable_plant.label[i]) Bidding Group ID $(renewable_plant.bidding_group_index[i]) not found."
            )
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------
