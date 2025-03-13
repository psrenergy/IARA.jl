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
    Branch

Collection representing the Branches in the system.
"""
@collection @kwdef mutable struct Branch <: AbstractCollection
    label::Vector{String} = []
    existing::Vector{Branch_Existence.T} = []
    capacity::Vector{Float64} = []
    reactance::Vector{Float64} = []
    line_model::Vector{Branch_LineModel.T} = []
    # index of the bus to in collection Bus
    bus_to::Vector{Int} = []
    # index of the bus from in collection Bus
    bus_from::Vector{Int} = []
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(branch::Branch, inputs::AbstractInputs)

Initialize the Branch collection from the database.
"""
function initialize!(branch::Branch, inputs::AbstractInputs)
    num_branches = PSRI.max_elements(inputs.db, "Branch")
    if num_branches == 0
        return nothing
    end

    branch.label = PSRI.get_parms(inputs.db, "Branch", "label")
    branch.line_model =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "Branch", "line_model"),
            Branch_LineModel.T,
        )
    branch.bus_to = PSRI.get_map(inputs.db, "Branch", "Bus", "to")
    branch.bus_from = PSRI.get_map(inputs.db, "Branch", "Bus", "from")

    update_time_series_from_db!(branch, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    update_time_series_from_db!(branch::Branch, db::DatabaseSQLite, period_date_time::DateTime)

Update the Branch collection time series from the database.
"""
function update_time_series_from_db!(branch::Branch, db::DatabaseSQLite, period_date_time::DateTime)
    date = Dates.format(period_date_time, "yyyymmddHHMMSS")
    branch.existing =
        @memoized_lru "branch-existing-$date" convert_to_enum.(
            PSRDatabaseSQLite.read_time_series_row(
                db,
                "Branch",
                "existing";
                date_time = period_date_time,
            ),
            Branch_Existence.T,
        )
    branch.capacity =
        @memoized_lru "branch-capacity-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "Branch",
            "capacity";
            date_time = period_date_time,
        )
    branch.reactance =
        @memoized_lru "branch-reactance-$date" PSRDatabaseSQLite.read_time_series_row(
            db,
            "Branch",
            "reactance";
            date_time = period_date_time,
        )
    return nothing
end

"""
    add_branch!(db::DatabaseSQLite; kwargs...)

Add a Branch to the database.

Required arguments: 
  - `label::String`: Branch label
  - `line_model::Branch_LineModel.T`: Line model (Branch_LineModel.AC or Branch_LineModel.DC)
    - _Default is_ `Branch_LineModel.AC`
  
Optional arguments:
  - `bus_to::String`: Bus label (only if the bus is already in the database)
  - `bus_from::String`: Bus label (only if the bus is already in the database)
  - `parameters::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).

--- 

**Time Series**

The `parameters` dataframe has columns that may be mandatory or not, depending on some configurations about the case.

Required columns:

  - `date_time::Vector{DateTime}`: date and time of the time series data.
  - `existing::Vector{Int}`: Whether the branch is existing or not (0 -> not existing, 1 -> existing)
  - `capacity::Vector{Float64}`: Branch capacity `[MWh]`
  - `reactance::Vector{Float64}`: Branch reactance `[p.u.]`
    - _Ignored if_ [`IARA.Branch_LineModel`](@ref) _is set to_ `DC`


Example:
```julia
IARA.add_branch!(db;
    label = "ac_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.Branch_Existence.EXISTS)],
        capacity = [15.0],
        reactance = [0.4],
    ),
    bus_from = "bus_2",
    bus_to = "bus_3",
)
```
"""
function add_branch!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "Branch"; sql_typed_kwargs...)
    return nothing
end

"""
    update_branch!(db::DatabaseSQLite, label::String; kwargs...)

Update the Branch named 'label' in the database.
"""
function update_branch!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "Branch",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_branch_relation!(db::DatabaseSQLite, branch_label::String; collection::String, relation_type::String, related_label::String)

Update the Branch named 'label' in the database.
"""
function update_branch_relation!(
    db::DatabaseSQLite,
    branch_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "Branch",
        collection,
        branch_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(branch::Branch)

Validate the Branch collection.
"""
function validate(branch::Branch)
    num_errors = 0
    for i in 1:length(branch)
        if isempty(branch.label[i])
            @error("Branch Label cannot be empty.")
            num_errors += 1
        end
        if branch.capacity[i] < 0
            @error(
                "Branch $(branch.label[i]) Capacity must be non-negative. Current value is $(branch.capacity[i])"
            )
            num_errors += 1
        end
        if branch.reactance[i] <= 0
            @error(
                "Branch $(branch.label[i]) Reactance must be positive. Current value is $(branch.reactance[i])"
            )
            num_errors += 1
        end
    end

    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, branch::Branch)

Validate the Branch within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, branch::Branch)
    buses = index_of_elements(inputs, Bus)

    num_errors = 0
    for i in 1:length(branch)
        if !(branch.bus_to[i] in buses)
            @error("Branch $(branch.label[i]) Bus To $(branch.bus_to[i]) not found.")
            num_errors += 1
        end
        if !(branch.bus_from[i] in buses)
            @error("Branch $(branch.label[i]) Bus From $(branch.bus_from[i]) not found.")
            num_errors += 1
        end
    end
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    is_dc(b::Branch, i::Int)

Check if the Branch at index 'i' is modeled as a DC Line.
"""
is_dc(b::Branch, i::Int) = b.line_model[i] == Branch_LineModel.DC

"""
    is_ac(b::Branch, i::Int)

Check if the Branch at index 'i' is modeled as an AC Line.
"""
is_ac(b::Branch, i::Int) = b.line_model[i] == Branch_LineModel.AC

"""
    is_branch_modeled_as_dc_line(inputs::AbstractInputs, idx::Int)

Check if the Branch at index 'idx' is modeled as a DC Line.
"""
is_branch_modeled_as_dc_line(inputs::AbstractInputs, idx::Int) =
    inputs.collections.branch.line_model[idx] == Branch_LineModel.DC

"""
    some_branch_does_not_have_dc_flag(inputs::AbstractInputs)

Check if not all Branches are modeled as DC Lines.
"""
some_branch_does_not_have_dc_flag(inputs::AbstractInputs) =
    any(l -> l != Branch_LineModel.DC, inputs.collections.branch.line_model)
