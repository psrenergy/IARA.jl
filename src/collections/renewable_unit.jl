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
    RenewableUnit

Renewable units are high-level data structures that represent non-dispatchable electricity generation.
"""
@collection @kwdef mutable struct RenewableUnit <: AbstractCollection
    label::Vector{String} = []
    existing::Vector{RenewableUnit_Existence.T} = []
    max_generation::Vector{Float64} = []
    om_cost::Vector{Float64} = []
    curtailment_cost::Vector{Float64} = []
    technology_type::Vector{Int} = []
    # index of the bus to which the renewable unit belongs in the collection Bus
    bus_index::Vector{Int} = []
    # index of the bidding group to which the renewable unit belongs in the collection BiddingGroup
    bidding_group_index::Vector{Int} = []
    generation_file::String = ""
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(renewable_unit::RenewableUnit, inputs)

Initialize the Renewable Unit collection from the database.
"""
function initialize!(renewable_unit::RenewableUnit, inputs::AbstractInputs)
    num_renewable_units = PSRI.max_elements(inputs.db, "RenewableUnit")
    if num_renewable_units == 0
        return nothing
    end

    renewable_unit.label = PSRI.get_parms(inputs.db, "RenewableUnit", "label")
    renewable_unit.technology_type =
        PSRI.get_parms(inputs.db, "RenewableUnit", "technology_type")
    renewable_unit.bus_index = PSRI.get_map(inputs.db, "RenewableUnit", "Bus", "id")
    renewable_unit.bidding_group_index = PSRI.get_map(inputs.db, "RenewableUnit", "BiddingGroup", "id")

    # Load time series files
    renewable_unit.generation_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "RenewableUnit", "generation")

    update_time_series_from_db!(renewable_unit, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(renewable_unit::RenewableUnit, db::DatabaseSQLite, period_date_time::DateTime)

Update the Renewable Unit collection time series from the database.
"""
function update_time_series_from_db!(
    renewable_unit::RenewableUnit,
    db::DatabaseSQLite,
    period_date_time::DateTime,
)
    renewable_unit.existing =
        convert_to_enum.(
            PSRDatabaseSQLite.read_time_series_row(
                db,
                "RenewableUnit",
                "existing";
                date_time = period_date_time,
            ),
            RenewableUnit_Existence.T,
        )
    renewable_unit.max_generation = PSRDatabaseSQLite.read_time_series_row(
        db,
        "RenewableUnit",
        "max_generation";
        date_time = period_date_time,
    )
    renewable_unit.om_cost = PSRDatabaseSQLite.read_time_series_row(
        db,
        "RenewableUnit",
        "om_cost";
        date_time = period_date_time,
    )
    renewable_unit.curtailment_cost = PSRDatabaseSQLite.read_time_series_row(
        db,
        "RenewableUnit",
        "curtailment_cost";
        date_time = period_date_time,
    )

    return nothing
end

"""
    add_renewable_unit!(db::DatabaseSQLite; kwargs...)

Add a Renewable Unit to the database.

Required arguments:
  - `label::String`: Renewable Unit label
  - `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).
  - `biddinggroup_id::String`: Bidding Group label (only if the BiddingGroup already exists)
    - _Required if_ [`IARA.RunMode`](@ref) _is not set to_ `TRAIN_MIN_COST`
  - `bus_id::String`: Bus label (only if the bus is already in the database)

Optional arguments:
  - `technology_type::Int`: Renewable Unit technology type (0 -> Solar, 1 -> Wind)  

---

**Time Series**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.

Required columns:

  - `date_time::Vector{DateTime}`: date and time of the time series data.
  - `existing::Vector{Int}`: Whether the renewable unit is existing or not (0 -> not existing, 1 -> existing)
  - `max_generation::Vector{Float64}`: Maximum generation of the renewable unit. `[MWh]`
  - `om_cost::Vector{Float64}`: O&M cost of the renewable unit. `[\$/MWh]`
  - `curtailment_cost::Vector{Float64}`: Curtailment cost of the renewable unit. `[\$/MWh]`

Example:
```julia
IARA.add_renewable_unit!(
    db;
    label = "Solar1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [80.0],
        om_cost = [0.0],
        curtailment_cost = [100.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)
```
"""
function add_renewable_unit!(db::DatabaseSQLite; kwargs...)
    PSRI.create_element!(db, "RenewableUnit"; kwargs...)
    return nothing
end

"""
    update_renewable_unit_time_series!(db::DatabaseSQLite, label::String; date_time::DateTime = DateTime(0), kwargs...)

Update time series attributes for the Renewable Unit named 'label' in the database.

Example:
```julia
IARA.update_renewable_unit_time_series!(db, "gnd_1"; max_generation = 4.5)
```
"""
function update_renewable_unit_time_series!(
    db::DatabaseSQLite,
    label::String;
    date_time::DateTime = DateTime(0),
    kwargs...,
)
    for (attribute, value) in kwargs
        PSRDatabaseSQLite.update_time_series_row!(
            db,
            "RenewableUnit",
            string(attribute),
            label,
            value;
            date_time = date_time,
        )
    end
    return db
end

"""
    update_renewable_unit!(db::DatabaseSQLite, label::String; kwargs...)

Update the Renewable Unit named 'label' in the database.
"""
function update_renewable_unit!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    for (attribute, value) in kwargs
        PSRI.set_parm!(
            db,
            "RenewableUnit",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_renewable_unit_relation!(db::DatabaseSQLite, renewable_unit_label::String; collection::String, relation_type::String, related_label::String)

Update the Renewable Unit named 'label' in the database.
"""
function update_renewable_unit_relation!(
    db::DatabaseSQLite,
    renewable_unit_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "RenewableUnit",
        collection,
        renewable_unit_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(renewable_unit::RenewableUnit)

Validate the Renewable Units' parameters. Return the number of errors found.
"""
function validate(renewable_unit::RenewableUnit)
    num_errors = 0
    for i in 1:length(renewable_unit)
        if isempty(renewable_unit.label[i])
            @error("Renewable Unit Label cannot be empty.")
            num_errors += 1
        end
        if renewable_unit.max_generation[i] < 0
            @error(
                "Renewable Unit $(renewable_unit.label[i]) Maximum generation must be non-negative. Current value is $(renewable_unit.max_generation[i])."
            )
            num_errors += 1
        end
        if renewable_unit.om_cost[i] < 0
            @error(
                "Renewable Unit $(renewable_unit.label[i]) O&M cost must be non-negative. Current value is $(renewable_unit.om_cost[i])."
            )
            num_errors += 1
        end
        if renewable_unit.curtailment_cost[i] < 0
            @error(
                "Renewable Unit $(renewable_unit.label[i]) Curtailment cost must be non-negative. Current value is $(renewable_unit.curtailment_cost[i])."
            )
            num_errors += 1
        end
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, renewable_unit::RenewableUnit)

Validate the Renewable Units' context within the inputs. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, renewable_unit::RenewableUnit)
    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup)

    num_errors = 0
    for i in 1:length(renewable_unit)
        if !(renewable_unit.bus_index[i] in buses)
            @error(
                "Renewable Unit $(renewable_unit.label[i]) Bus ID $(renewable_unit.bus_index[i]) not found."
            )
            num_errors += 1
        end
        if !is_null(renewable_unit.bidding_group_index[i]) &&
           !(renewable_unit.bidding_group_index[i] in bidding_groups)
            @error(
                "Renewable Unit $(renewable_unit.label[i]) Bidding Group ID $(renewable_unit.bidding_group_index[i]) not found."
            )
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------
