#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

export add_reserve!
export update_reserve!

@collection @kwdef mutable struct Reserve <: AbstractCollection
    label::Vector{String} = []
    constraint_type::Vector{Reserve_ConstraintType.T} = []
    direction::Vector{Reserve_Direction.T} = []
    violation_cost::Vector{Float64} = []
    angular_coefficient::Vector{Float64} = []
    linear_coefficient::Vector{Float64} = []
    thermal_plant_indices::Vector{Vector{Int}} = []
    hydro_plant_indices::Vector{Vector{Int}} = []
    battery_indices::Vector{Vector{Int}} = []
    requirement_file::String = ""
end

function initialize!(reserve::Reserve, inputs::AbstractInputs)
    num_reserves = PSRI.max_elements(inputs.db, "Reserve")
    if num_reserves == 0
        return nothing
    end

    reserve.label = PSRI.get_parms(inputs.db, "Reserve", "label")
    reserve.constraint_type = PSRI.get_parms(inputs.db, "Reserve", "constraint_type") .|> Reserve_ConstraintType.T
    reserve.direction = PSRI.get_parms(inputs.db, "Reserve", "direction") .|> Reserve_Direction.T
    reserve.violation_cost = PSRI.get_parms(inputs.db, "Reserve", "violation_cost")
    reserve.angular_coefficient = PSRI.get_parms(inputs.db, "Reserve", "angular_coefficient")
    reserve.linear_coefficient = PSRI.get_parms(inputs.db, "Reserve", "linear_coefficient")
    reserve.thermal_plant_indices = PSRI.get_vector_map(inputs.db, "Reserve", "ThermalPlant", "id")
    reserve.hydro_plant_indices = PSRI.get_vector_map(inputs.db, "Reserve", "HydroPlant", "id")
    reserve.battery_indices = PSRI.get_vector_map(inputs.db, "Reserve", "Battery", "id")

    reserve.requirement_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "Reserve", "reserve_requirement")

    update_time_series_from_db!(reserve, inputs.db, initial_date_time(inputs))

    return nothing
end

"""
    validate(reserve::Reserve)

Validate the Reserve's parameters. Return the number of errors found.
"""
function validate(reserve::Reserve)
    num_errors = 0
    for i in 1:length(reserve)
        reserve_label = reserve.label[i]
        if reserve.violation_cost[i] <= 0
            @error "Violation cost for reserve $(reserve_label) must be greater than zero."
            num_errors += 1
        end
        if isempty(reserve.thermal_plant_indices[i]) && isempty(reserve.hydro_plant_indices[i]) &&
           isempty(reserve.battery_indices[i])
            @error "Reserve $(reserve_label) must be associated with at least one thermal plant, hydro plant, or battery."
            num_errors += 1
        end
    end
    return num_errors
end

"""
    validate_relations(reserve::Reserve, inputs)

Validate the relations of the Reserve's parameters with the other collections. Return the number of errors found.
"""
function validate_relations(inputs::AbstractInputs, reserve::Reserve)
    num_errors = 0
    return num_errors
end

"""
    update_time_series_from_db!(reserve::Reserve, db::DatabaseSQLite, stage_date_time::DateTime)

Update the Reserve collection time series from the database.
"""
function update_time_series_from_db!(reserve::Reserve, db::DatabaseSQLite, stage_date_time::DateTime)
    return nothing
end

"""
    add_reserve!(db::DatabaseSQLite; kwargs...)

Add a Reserve to the database.
"""
function add_reserve!(db::DatabaseSQLite; kwargs...)
    kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "Reserve"; kwargs...)
    return nothing
end

"""
    update_reserve!(db::DatabaseSQLite, label::String; kwargs...)

Update the Reserve named 'label' in the database.
"""
function update_reserve!(db::DatabaseSQLite, label::String; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "Reserve",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

"""
    reserve_angular_coefficient(inputs, idx::Int)

Return the coefficient 'a' of the reserve in position `idx`. Fullfills with one if empty.
"""
reserve_angular_coefficient(inputs::AbstractInputs, idx::Int) =
    is_null(inputs.collections.reserve.angular_coefficient[idx]) ? 1.0 :
    inputs.collections.reserve.angular_coefficient[idx]

"""
    reserve_linear_coefficient(inputs, idx::Int)

Return the coefficient 'b' of the reserve in position `idx`. Fullfills with zero if empty.
"""
reserve_linear_coefficient(inputs::AbstractInputs, idx::Int) =
    is_null(inputs.collections.reserve.linear_coefficient[idx]) ? 0.0 :
    inputs.collections.reserve.linear_coefficient[idx]

has_thermal_plant(reserve::Reserve, idx::Int) = !isempty(reserve.thermal_plant_indices[idx])
has_hydro_plant(reserve::Reserve, idx::Int) = !isempty(reserve.hydro_plant_indices[idx])
has_battery(reserve::Reserve, idx::Int) = !isempty(reserve.battery_indices[idx])
is_equality(reserve::Reserve, idx::Int) = reserve.constraint_type[idx] == Reserve_ConstraintType.EQUALITY
is_inequality(reserve::Reserve, idx::Int) = reserve.constraint_type[idx] == Reserve_ConstraintType.INEQUALITY

"""
    reserve_is_of_type_equality(inputs, idx::Int)

Return true if the reserve in position `idx` is of type equality.
"""
reserve_is_of_type_equality(inputs::AbstractInputs, idx::Int) =
    reserve_constraint_type(inputs, idx) == Reserve_ConstraintType.EQUALITY

"""
    reserve_is_of_type_inequality(inputs, idx::Int)

Return true if the reserve in position `idx` is of type inequality.
"""
reserve_is_of_type_inequality(inputs::AbstractInputs, idx::Int) =
    reserve_constraint_type(inputs, idx) == Reserve_ConstraintType.INEQUALITY

"""
    reserve_has_direction_up(inputs, idx::Int)

Return true if the reserve in position `idx` has direction up.
"""
reserve_has_direction_up(inputs::AbstractInputs, idx::Int) = reserve_direction(inputs, idx) == Reserve_Direction.UP

"""
    reserve_has_direction_down(inputs, idx::Int)

Return true if the reserve in position `idx` has direction down.
"""
reserve_has_direction_down(inputs::AbstractInputs, idx::Int) = reserve_direction(inputs, idx) == Reserve_Direction.DOWN
