#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

export add_demand!
export update_demand!
export update_demand_relation!

# ---------------------------------------------------------------------
# Collection definition
# ---------------------------------------------------------------------

"""
    Demand

Demand collection definition.
"""
@collection @kwdef mutable struct Demand <: AbstractCollection
    label::Vector{String} = []
    demand_type::Vector{Demand_DemandType.T} = []
    existing::Vector{Bool} = []
    max_shift_up::Vector{Float64} = []
    max_shift_down::Vector{Float64} = []
    curtailment_cost::Vector{Float64} = []
    max_curtailment::Vector{Float64} = []
    # index of the bus to which the thermal plant belongs in the collection Bus
    bus_index::Vector{Int} = []
    demand_file::String = ""
    elastic_demand_price_file::String = ""
    window_file::String = ""
    # cache
    _number_of_flexible_demand_windows::Vector{Int} = Vector{Int}(undef, 0)
    _blocks_in_flexible_demand_window::Vector{Vector{Vector{Int}}} =
        Vector{Vector{Vector{Int}}}(undef, 0)
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(demand::Demand, inputs)

Initialize the Demand collection from the database.
"""
function initialize!(demand::Demand, inputs::AbstractInputs)
    num_demands = PSRI.max_elements(inputs.db, "Demand")
    if num_demands == 0
        return nothing
    end

    demand.label = PSRI.get_parms(inputs.db, "Demand", "label")
    demand.demand_type = PSRI.get_parms(inputs.db, "Demand", "demand_type") .|> Demand_DemandType.T
    demand.max_shift_up = PSRI.get_parms(inputs.db, "Demand", "max_shift_up")
    demand.max_shift_down = PSRI.get_parms(inputs.db, "Demand", "max_shift_down")
    demand.curtailment_cost = PSRI.get_parms(inputs.db, "Demand", "curtailment_cost")
    demand.max_curtailment = PSRI.get_parms(inputs.db, "Demand", "max_curtailment")
    demand.bus_index = PSRI.get_map(inputs.db, "Demand", "Bus", "id")

    demand.demand_file = PSRDatabaseSQLite.read_time_series_file(inputs.db, "Demand", "demand")
    demand.elastic_demand_price_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "Demand", "elastic_demand_price")
    demand.window_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "Demand", "demand_window")

    update_time_series_from_db!(demand, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(demand::Demand, db::DatabaseSQLite, stage_date_time::DateTime)

Update the Demand collection time series from the database.
"""
function update_time_series_from_db!(demand::Demand, db::DatabaseSQLite, stage_date_time::DateTime)
    demand.existing = PSRDatabaseSQLite.read_time_series_row(
        db,
        "Demand",
        "existing";
        date_time = stage_date_time,
    )

    return nothing
end

"""
    add_demand!(db::DatabaseSQLite; kwargs...)

Add a Demand to the database.

Required arguments:

  - `label::String`: Demand label
  - `demand_type::Demand_DemandType.T`: Demand type ([`IARA.Demand_DemandType`](@ref))
    - _Default set to_ `Demand_DemandType.INELASTIC`
  - `bus_id::String`: Bus label (only if the Bus already exists).
  - `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).

Optional arguments:

  - `max_shift_up::Float64`: Maximum shift up `[MWh]`
  - `max_shift_down::Float64`: Maximum shift down `[MWh]`
  - `curtailment_cost::Float64`: Curtailment cost `[\$/MWh]`
  - `max_curtailment::Float64`: Maximum curtailment `[MWh]`
  
--- 

**Time Series**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.

Required columns: 

  - `date_time::Vector{DateTime}`: date and time of the time series data.
  - `existing::Vector{Int}`: Whether the demand is existing or not (0 -> not existing, 1 -> existing)


"""
function add_demand!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "Demand"; sql_typed_kwargs...)
    return nothing
end

"""
    update_demand!(db::DatabaseSQLite, label::String; kwargs...)

Update the Demand named 'label' in the database.
"""
function update_demand!(db::DatabaseSQLite, label::String; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(db, "Demand", string(attribute), label, value)
    end
    return db
end

"""
    update_demand_relation!(db::DatabaseSQLite, demand_label::String; collection::String, relation_type::String, related_label::String)

Update the Demand named 'label' in the database.
"""
function update_demand_relation!(
    db::DatabaseSQLite,
    demand_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "Demand",
        collection,
        demand_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(demand::Demand)

Validate the Demand's parameters. Return the number of errors found.
"""
function validate(demand::Demand)
    num_errors = 0
    for i in 1:length(demand)
        if isempty(demand.label[i])
            @error("Demand Label cannot be empty.")
            num_errors += 1
        end
        if demand.max_shift_up[i] < 0
            @error("Demand $(demand.label[i]) Max Shift Up must be non-negative.")
            num_errors += 1
        end
        if demand.max_shift_down[i] < 0
            @error("Demand $(demand.label[i]) Max Shift Down must be non-negative.")
            num_errors += 1
        end
        if demand.curtailment_cost[i] < 0
            @error("Demand $(demand.label[i]) Curtailment Cost must be non-negative.")
            num_errors += 1
        end
        if demand.max_curtailment[i] < 0
            @error("Demand $(demand.label[i]) Max Curtailment must be non-negative.")
            num_errors += 1
        end
        if demand.demand_type[i] == Demand_DemandType.FLEXIBLE
            if is_null(demand.max_shift_up[i])
                @error(
                    "Demand $(demand.label[i]) Max Shift Up must be defined for flexible demands."
                )
                num_errors += 1
            elseif demand.max_shift_up[i] <= 0
                @error(
                    "Demand $(demand.label[i]) Max Shift Up must be positive for flexible demands."
                )
                num_errors += 1
            end
            if is_null(demand.max_shift_down[i])
                @error(
                    "Demand $(demand.label[i]) Max Shift Down must be defined for flexible demands."
                )
                num_errors += 1
            elseif demand.max_shift_down[i] <= 0
                @error(
                    "Demand $(demand.label[i]) Max Shift Down must be positive for flexible demands."
                )
                num_errors += 1
            end
            if is_null(demand.curtailment_cost[i])
                @error(
                    "Demand $(demand.label[i]) Curtailment Cost must be defined for flexible demands."
                )
                num_errors += 1
            elseif demand.curtailment_cost[i] <= 0
                @error(
                    "Demand $(demand.label[i]) Curtailment Cost must be positive for flexible demands."
                )
                num_errors += 1
            end
            if is_null(demand.max_curtailment[i])
                @error(
                    "Demand $(demand.label[i]) Max Curtailment must be defined for flexible demands."
                )
                num_errors += 1
            elseif demand.max_curtailment[i] < 0
                @error(
                    "Demand $(demand.label[i]) Max Curtailment must be non-negative for flexible demands."
                )
                num_errors += 1
            end
        end
    end
    return num_errors
end

"""
    validate_relations(inputs, demand::Demand)

Validate the Demand's references. Return the number of errors found.
"""
function validate_relations(inputs::AbstractInputs, demand::Demand)
    buses = index_of_elements(inputs, Bus)

    num_errors = 0
    for i in 1:length(demand)
        if !(demand.bus_index[i] in buses)
            @error("Demand $(demand.label[i]) Bus ID $(demand.bus_index[i]) not found.")
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    elastic_demand_labels(inputs)

Return the labels of elastic Demands.
"""
elastic_demand_labels(inputs::AbstractInputs) =
    [demand_label(inputs, d) for d in index_of_elements(inputs, Demand; filters = [is_elastic])]

"""
    flexible_demand_labels(inputs)

Return the labels of flexible Demands.
"""
flexible_demand_labels(inputs::AbstractInputs) =
    [demand_label(inputs, d) for d in index_of_elements(inputs, Demand; filters = [is_flexible])]

"""
    index_among_elastic_demands(inputs, idx::Int)

Return the index of the Demand in position 'idx' among the elastic Demands.
"""
index_among_elastic_demands(inputs::AbstractInputs, idx::Int) =
    findfirst(isequal(idx), index_of_elements(inputs, Demand; filters = [is_elastic]))

"""
    number_of_flexible_demand_windows(inputs, idx::Int)

Return the number of windows for the flexible Demand in position 'idx'.
"""
number_of_flexible_demand_windows(inputs::AbstractInputs, idx::Int) =
    inputs.collections.demand._number_of_flexible_demand_windows[idx]

"""
    blocks_in_flexible_demand_window(inputs, idx::Int, w::Int)

Return the set of blocks in the window 'w' of the flexible Demand in position 'idx'.
"""
blocks_in_flexible_demand_window(inputs::AbstractInputs, idx::Int, w::Int) =
    inputs.collections.demand._blocks_in_flexible_demand_window[idx][w]

is_elastic(d::Demand, i::Int) = d.demand_type[i] == Demand_DemandType.ELASTIC
is_flexible(d::Demand, i::Int) = d.demand_type[i] == Demand_DemandType.FLEXIBLE
is_inelastic(d::Demand, i::Int) = d.demand_type[i] == Demand_DemandType.INELASTIC
