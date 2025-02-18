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
    DemandUnit

DemandUnit collection definition.
"""
@collection @kwdef mutable struct DemandUnit <: AbstractCollection
    label::Vector{String} = []
    demand_unit_type::Vector{DemandUnit_DemandType.T} = []
    existing::Vector{DemandUnit_Existence.T} = []
    max_shift_up::Vector{Float64} = []
    max_shift_down::Vector{Float64} = []
    curtailment_cost::Vector{Float64} = []
    max_curtailment::Vector{Float64} = []
    max_demand::Vector{Float64} = []
    # index of the bus to which the thermal unit belongs in the collection Bus
    bus_index::Vector{Int} = []
    demand_ex_ante_file::String = ""
    demand_ex_post_file::String = ""
    elastic_demand_price_file::String = ""
    window_file::String = ""
    # cache
    _number_of_flexible_demand_windows::Vector{Int} = Vector{Int}(undef, 0)
    _subperiods_in_flexible_demand_window::Vector{Vector{Vector{Int}}} =
        Vector{Vector{Vector{Int}}}(undef, 0)
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(demand_unit::DemandUnit, inputs::AbstractInputs)

Initialize the Demand collection from the database.
"""
function initialize!(demand_unit::DemandUnit, inputs::AbstractInputs)
    num_demands = PSRI.max_elements(inputs.db, "DemandUnit")
    if num_demands == 0
        return nothing
    end

    demand_unit.label = PSRI.get_parms(inputs.db, "DemandUnit", "label")
    demand_unit.demand_unit_type =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "DemandUnit", "demand_unit_type"),
            DemandUnit_DemandType.T,
        )
    demand_unit.max_shift_up = PSRI.get_parms(inputs.db, "DemandUnit", "max_shift_up")
    demand_unit.max_shift_down = PSRI.get_parms(inputs.db, "DemandUnit", "max_shift_down")
    demand_unit.curtailment_cost = PSRI.get_parms(inputs.db, "DemandUnit", "curtailment_cost")
    demand_unit.max_curtailment = PSRI.get_parms(inputs.db, "DemandUnit", "max_curtailment")
    demand_unit.bus_index = PSRI.get_map(inputs.db, "DemandUnit", "Bus", "id")
    demand_unit.max_demand = PSRI.get_parms(inputs.db, "DemandUnit", "max_demand")

    demand_unit.demand_ex_ante_file = PSRDatabaseSQLite.read_time_series_file(inputs.db, "DemandUnit", "demand_ex_ante")
    demand_unit.demand_ex_post_file = PSRDatabaseSQLite.read_time_series_file(inputs.db, "DemandUnit", "demand_ex_post")
    demand_unit.elastic_demand_price_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "DemandUnit", "elastic_demand_price")
    demand_unit.window_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "DemandUnit", "demand_window")

    update_time_series_from_db!(demand_unit, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(demand_unit::DemandUnit, db::DatabaseSQLite, period_date_time::DateTime)

Update the Demand collection time series from the database.
"""
function update_time_series_from_db!(demand_unit::DemandUnit, db::DatabaseSQLite, period_date_time::DateTime)
    demand_unit.existing =
        convert_to_enum.(
            PSRDatabaseSQLite.read_time_series_row(
                db,
                "DemandUnit",
                "existing";
                date_time = period_date_time,
            ),
            DemandUnit_Existence.T,
        )
    return nothing
end

"""
    add_demand_unit!(db::DatabaseSQLite; kwargs...)

Add a Demand to the database.

Required arguments:

  - `label::String`: Demand label
  - `demand_unit_type::DemandUnit_DemandType.T`: Demand type ([`IARA.DemandUnit_DemandType`](@ref))
    - _Default set to_ `DemandUnit_DemandType.INELASTIC`
  - `bus_id::String`: Bus label (only if the Bus already exists).
  - `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).

Optional arguments:

  - `max_shift_up::Float64`: Maximum shift up `[MWh]`
  - `max_shift_down::Float64`: Maximum shift down `[MWh]`
  - `curtailment_cost::Float64`: Curtailment cost `[\$/MWh]`
  - `max_curtailment::Float64`: Maximum curtailment `[MWh]`
  - `max_demand::Float64`: Maximum demand `[MW]`
  
--- 

**Time Series**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.

Required columns: 

  - `date_time::Vector{DateTime}`: date and time of the time series data.
  - `existing::Vector{Int}`: Whether the demand is existing or not (0 -> not existing, 1 -> existing)

Example:
```julia
IARA.add_demand_unit!(db;
    label = "Demand1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Island",
)
``` 
"""
function add_demand_unit!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "DemandUnit"; sql_typed_kwargs...)
    return nothing
end

"""
    update_demand!(db::DatabaseSQLite, label::String; kwargs...)

Update the Demand named 'label' in the database.
"""
function update_demand_unit!(db::DatabaseSQLite, label::String; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(db, "DemandUnit", string(attribute), label, value)
    end
    return db
end

"""
    update_demand_relation_unit!(db::DatabaseSQLite, demand_label::String; collection::String, relation_type::String, related_label::String)

Update the Demand named 'label' in the database.

Example:
```julia
IARA.update_demand_relation_unit!(
    db, 
    "dem_1"; 
    collection = "Bus", 
    relation_type = "id", 
    related_label = "bus_3"
)
```
"""
function update_demand_relation_unit!(
    db::DatabaseSQLite,
    demand_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    if collection == "BiddingGroup"
        error("It's not possible to relate a DemandUnit to a Bidding Group.")
    end
    PSRI.set_related!(
        db,
        "DemandUnit",
        collection,
        demand_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(demand_unit::DemandUnit)

Validate the Demand's parameters. Return the number of errors found.
"""
function validate(demand_unit::DemandUnit)
    num_errors = 0
    for i in 1:length(demand_unit)
        if isempty(demand_unit.label[i])
            @error("Demand Unit Label cannot be empty.")
            num_errors += 1
        end
        if demand_unit.max_shift_up[i] < 0
            @error("Demand Unit $(demand_unit.label[i]) Max Shift Up must be non-negative.")
            num_errors += 1
        end
        if demand_unit.max_shift_down[i] < 0
            @error("Demand Unit $(demand_unit.label[i]) Max Shift Down must be non-negative.")
            num_errors += 1
        end
        if demand_unit.curtailment_cost[i] < 0
            @error("Demand Unit $(demand_unit.label[i]) Curtailment Cost must be non-negative.")
            num_errors += 1
        end
        if demand_unit.max_curtailment[i] < 0
            @error("Demand Unit $(demand_unit.label[i]) Max Curtailment must be non-negative.")
            num_errors += 1
        end
        if demand_unit.max_demand[i] < 0
            @error("Demand Unit $(demand_unit.label[i]) Max Demand must be non-negative.")
            num_errors += 1
        end
        if demand_unit.demand_unit_type[i] == DemandUnit_DemandType.FLEXIBLE
            if is_null(demand_unit.max_shift_up[i])
                @error(
                    "Demand Unit $(demand_unit.label[i]) Max Shift Up must be defined for flexible demands."
                )
                num_errors += 1
            elseif demand_unit.max_shift_up[i] <= 0
                @error(
                    "Demand Unit $(demand_unit.label[i]) Max Shift Up must be positive for flexible demands."
                )
                num_errors += 1
            end
            if is_null(demand_unit.max_shift_down[i])
                @error(
                    "Demand Unit $(demand_unit.label[i]) Max Shift Down must be defined for flexible demands."
                )
                num_errors += 1
            elseif demand_unit.max_shift_down[i] <= 0
                @error(
                    "Demand Unit $(demand_unit.label[i]) Max Shift Down must be positive for flexible demands."
                )
                num_errors += 1
            end
            if is_null(demand_unit.curtailment_cost[i])
                @error(
                    "Demand Unit $(demand_unit.label[i]) Curtailment Cost must be defined for flexible demands."
                )
                num_errors += 1
            elseif demand_unit.curtailment_cost[i] <= 0
                @error(
                    "Demand Unit $(demand_unit.label[i]) Curtailment Cost must be positive for flexible demands."
                )
                num_errors += 1
            end
            if is_null(demand_unit.max_curtailment[i])
                @error(
                    "Demand Unit $(demand_unit.label[i]) Max Curtailment must be defined for flexible demands."
                )
                num_errors += 1
            elseif demand_unit.max_curtailment[i] < 0
                @error(
                    "Demand Unit $(demand_unit.label[i]) Max Curtailment must be non-negative for flexible demands."
                )
                num_errors += 1
            end
        end
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, demand_unit::DemandUnit)

Validate the Demand's context within the inputs. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, demand_unit::DemandUnit)
    buses = index_of_elements(inputs, Bus)

    num_errors = 0
    for i in 1:length(demand_unit)
        if !(demand_unit.bus_index[i] in buses)
            @error("Demand Unit $(demand_unit.label[i]) Bus ID $(demand_unit.bus_index[i]) not found.")
            num_errors += 1
        end
    end
    if read_ex_ante_demand_file(inputs) && demand_unit.demand_ex_ante_file == "" && length(demand_unit) > 0
        @error(
            "The option demand_scenarios_files is set to $(demand_scenarios_files(inputs)), but no ex_ante demand file was linked."
        )
        num_errors += 1
    end
    if read_ex_post_demand_file(inputs) && demand_unit.demand_ex_post_file == "" && length(demand_unit) > 0
        @error(
            "The option demand_scenarios_files is set to $(demand_scenarios_files(inputs)), but no ex_post demand file was linked."
        )
        num_errors += 1
    end
    if !read_ex_ante_demand_file(inputs) && demand_unit.demand_ex_ante_file != "" && length(demand_unit) > 0
        @warn(
            "The option demand_scenarios_files is set to $(demand_scenarios_files(inputs)), but an ex_ante demand file was linked.
            This file will be ignored.")
    end
    if !read_ex_post_demand_file(inputs) && demand_unit.demand_ex_post_file != "" && length(demand_unit) > 0
        @warn(
            "The option demand_scenarios_files is set to $(demand_scenarios_files(inputs)), but an ex_post demand file was linked.
            This file will be ignored.")
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    elastic_demand_labels(inputs::AbstractInputs)

Return the labels of elastic Demands.
"""
elastic_demand_labels(inputs::AbstractInputs) =
    [demand_unit_label(inputs, d) for d in index_of_elements(inputs, DemandUnit; filters = [is_elastic])]

"""
    flexible_demand_labels(inputs::AbstractInputs)

Return the labels of flexible Demands.
"""
flexible_demand_labels(inputs::AbstractInputs) =
    [demand_unit_label(inputs, d) for d in index_of_elements(inputs, DemandUnit; filters = [is_flexible])]

"""
    index_among_elastic_demands(inputs::AbstractInputs, idx::Int)

Return the index of the Demand in position 'idx' among the elastic Demands.
"""
index_among_elastic_demands(inputs::AbstractInputs, idx::Int) =
    findfirst(isequal(idx), index_of_elements(inputs, DemandUnit; filters = [is_elastic]))

"""
    number_of_flexible_demand_windows(inputs::AbstractInputs, idx::Int)

Return the number of windows for the flexible Demand in position 'idx'.
"""
number_of_flexible_demand_windows(inputs::AbstractInputs, idx::Int) =
    inputs.collections.demand_unit._number_of_flexible_demand_windows[idx]

"""
    subperiods_in_flexible_demand_window(inputs::AbstractInputs, idx::Int, w::Int)

Return the set of subperiods in the window 'w' of the flexible Demand in position 'idx'.
"""
subperiods_in_flexible_demand_window(inputs::AbstractInputs, idx::Int, w::Int) =
    inputs.collections.demand_unit._subperiods_in_flexible_demand_window[idx][w]

"""
    is_elastic(d::DemandUnit, i::Int)

Return true if the Demand in position 'i' is `IARA.DemandUnit_DemandType.ELASTIC`.
"""
is_elastic(d::DemandUnit, i::Int) = d.demand_unit_type[i] == DemandUnit_DemandType.ELASTIC

"""
    is_flexible(d::DemandUnit, i::Int) 

Return true if the Demand in position 'i' is `IARA.DemandUnit_DemandType.FLEXIBLE`.
"""
is_flexible(d::DemandUnit, i::Int) = d.demand_unit_type[i] == DemandUnit_DemandType.FLEXIBLE

"""
    is_inelastic(d::DemandUnit, i::Int)

Return true if the Demand in position 'i' is `IARA.DemandUnit_DemandType.INELASTIC`.
"""
is_inelastic(d::DemandUnit, i::Int) = d.demand_unit_type[i] == DemandUnit_DemandType.INELASTIC

function demand_mw_to_gwh(
    inputs::AbstractInputs,
    demand_ts::Float64,
    demand_index::Int,
    subperiod::Int,
)
    return demand_ts * demand_unit_max_demand(inputs, demand_index) * subperiod_duration_in_hours(inputs, subperiod) *
           MW_to_GW()
end
