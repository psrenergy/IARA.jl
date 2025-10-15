#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function locate_inputs_in_args(args...)
    for arg in args
        if arg isa Inputs
            return arg
        end
    end
    return error("Inputs not found in arguments.")
end

function locate_run_time_options_in_args(args...)
    for arg in args
        if arg isa RunTimeOptions
            return arg
        end
    end
    return error("RunTimeOptions not found in arguments.")
end

function locate_action_in_args(args...)
    for arg in args
        if isa(arg, DataType) && arg <: AbstractAction
            return arg
        end
    end
    return error("Action not found in arguments.")
end

function m3_per_second_to_hm3_per_hour()
    return 3600 / 1e6
end

function MW_to_GW()
    return 1e-3
end

function money_to_thousand_money()
    return 1e-3
end

function per_minute_to_per_hour()
    return 60
end

function date_time_from_period(inputs::Inputs, period::Int)
    if time_series_step(inputs) == Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
        return initial_date_time(inputs) + Dates.Month(period - 1)
    elseif time_series_step(inputs) == Configurations_TimeSeriesStep.FROZEN_TIME
        if cyclic_policy_graph(inputs)
            return initial_date_time(inputs)
        else
            error("Date time from period is undefined for linear policy graphs with frozen time step.")
        end
    else
        error("Time series step $(time_series_step(inputs)) not supported.")
    end
end

function period_from_date_time(
    inputs::Inputs,
    date_time::DateTime;
    initial_date_time::DateTime = initial_date_time(inputs),
)
    if time_series_step(inputs) == Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
        year_difference = Dates.year(date_time) - Dates.year(initial_date_time)
        month_difference = Dates.month(date_time) - Dates.month(initial_date_time)
        return 12 * year_difference + month_difference + 1
    else
        error("Time series step $(time_series_step(inputs)) not supported.")
    end
end

function period_index_in_year(inputs::Inputs, period::Int)
    if time_series_step(inputs) == Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
        date_time = date_time_from_period(inputs, period)
        return Dates.month(date_time)
    elseif time_series_step(inputs) == Configurations_TimeSeriesStep.FROZEN_TIME
        if cyclic_policy_graph(inputs)
            return mod1(period, periods_per_year(inputs))
        else
            error("Period index in year is undefined for linear policy graphs with frozen time step.")
        end
    else
        error("Time series step $(time_series_step(inputs)) not supported.")
    end
end

function get_total_max_generation(inputs::Inputs, run_time_options::RunTimeOptions)
    max_generation = 0.0

    # Sum max generation from all unit types
    for h in index_of_elements(inputs, HydroUnit; run_time_options)
        max_generation += hydro_unit_max_generation(inputs, h)
    end
    for t in index_of_elements(inputs, ThermalUnit; run_time_options)
        max_generation += thermal_unit_max_generation(inputs, t)
    end
    for r in index_of_elements(inputs, RenewableUnit; run_time_options)
        max_generation += renewable_unit_max_generation(inputs, r)
    end

    return max_generation
end

function get_lower_bound(inputs::Inputs, run_time_options::RunTimeOptions)
    if is_current_asset_owner_price_taker(inputs, run_time_options)
        # Price takers use historical spot prices as max price reference
        max_price = get_max_price(inputs, run_time_options)
    elseif is_current_asset_owner_price_maker(inputs, run_time_options)
        # Price makers can potentially receive deficit cost when demand is unmet
        max_price = demand_deficit_cost(inputs)
    else
        return 0.0
    end

    max_generation = get_total_max_generation(inputs, run_time_options)
    total_subperiod_hours = sum(subperiod_duration_in_hours(inputs))

    # Lower bound represents worst-case negative revenue scenario
    return -max_price * max_generation * total_subperiod_hours
end

function get_nash_equilibrium_previous_output_path(inputs::Inputs, run_time_options::RunTimeOptions)
    # For Nash equilibrium iterations, get the path from the previous step
    nash_iter = nash_equilibrium_iteration(inputs, run_time_options)
    if nash_iter > 0
        if nash_iter == 1
            # For iteration 1, look in the initialization directory
            return joinpath(output_path(inputs.args), "nash_equilibrium_initialization")
        else
            # For iteration N > 1, look in iteration N-1 directory
            return joinpath(output_path(inputs.args), "nash_equilibrium_iteration_$(nash_iter - 1)")
        end
    else
        return output_path(inputs, run_time_options)
    end
end

function find_load_marginal_cost_file(dir_path::String)
    # Try to find load_marginal_cost file with various suffixes in priority order
    base_name = "load_marginal_cost"
    possible_suffixes = [
        "_ex_post_commercial",
        "_ex_ante_commercial",
        "_ex_post_physical",
        "_ex_ante_physical",
        "",  # Try base name without suffix as fallback
    ]

    for suffix in possible_suffixes
        file_path = joinpath(dir_path, base_name * suffix)
        if isfile(file_path * ".csv")
            return file_path
        end
    end

    return error("Load marginal cost file not found in directory: $dir_path")
end

function get_max_price(inputs::Inputs, run_time_options::RunTimeOptions)
    dir_path = get_nash_equilibrium_previous_output_path(inputs, run_time_options)
    spot_price_file = find_load_marginal_cost_file(dir_path)
    return get_maximum_value_of_time_series(spot_price_file)
end

function variable_aggregation_type(unit::String)
    aggregate_by_sum = ["MWh", "GWh", "\$"]
    aggregate_by_average = ["m3/s", "m³/s", "MW", "p.u.", "\$/MWh"]
    aggregate_by_last_value = ["hm3", "hm³"]

    if unit in aggregate_by_sum
        return Configurations_VariableAggregationType.SUM
    elseif unit in aggregate_by_average
        return Configurations_VariableAggregationType.AVERAGE
    elseif unit in aggregate_by_last_value
        return Configurations_VariableAggregationType.LAST_VALUE
    else
        error("Unexpected unit $unit.")
    end
end

function is_null(value)
    return PSRI.PSRDatabaseSQLite._is_null_in_db(value)
end

function null_value(type)
    return PSRDatabaseSQLite._psrdatabasesqlite_null_value(type)
end

"""
    build_sql_typed_kwargs(kwargs::Dict{Symbol, T}) where T

Converts Enum values in the kwargs to their corresponding Int values for SQL purposes, keeping other values unchanged.
"""
function build_sql_typed_kwargs(kwargs)
    sql_typed_kwargs = Dict{Symbol, Any}()
    for (key, value) in kwargs
        if isa(value, EnumX.Enum)
            sql_typed_kwargs[key] = Int(value)
        else
            sql_typed_kwargs[key] = value
        end
    end
    return sql_typed_kwargs
end

"""
    time_series_dataframe(path::String)

Reads a time series from a file and returns a DataFrame.
"""
function time_series_dataframe(path::String)
    # get file extension
    file, ext = splitext(path)
    quiver_file_implementation = if ext == ".csv"
        Quiver.csv
    elseif ext == ".quiv"
        Quiver.binary
    else
        error("File extension $ext not supported.")
    end

    return Quiver.file_to_df(file, quiver_file_implementation)
end

"""
    link_time_series_to_file(db::DatabaseSQLite, table_name::String; kwargs...)

Links a time series to a file in the database.

Each collection in the database can be linked to different time series files.

The possible files for each collection are:

$(PSRDatabaseSQLite.time_series_files_docstrings(model_directory()))

For more information about these files, please refer to the [Input Files](https://psrenergy.github.io/IARA.jl/dev/input_files.html) documentation.


Example:
```julia
IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_ante = "solar_generation",
)
```
"""
function link_time_series_to_file(
    db::DatabaseSQLite,
    table_name::String;
    kwargs...,
)
    return PSRI.link_series_to_file(db, table_name; kwargs...)
end

"""
    delete_element!(db::DatabaseSQLite, collection::String, label::String)

Deletes an element from a collection in the database.
"""
function delete_element!(db::DatabaseSQLite, collection::String, label::String)
    return PSRI.delete_element!(db, collection, label)
end

function enum_name_to_string(enum::EnumX.Enum)
    return String(Symbol(enum))
end

function marginal_cost_to_opportunity_cost(
    inputs::Inputs,
    water_marginal_cost::AbstractArray{Float64, 2},
    hydro_unit_indexes::Vector{Int},
)
    hydro_opportunity_cost = zeros(number_of_subperiods(inputs), length(hydro_unit_indexes))

    @assert hydro_balance_subperiod_resolution(inputs) ==
            Configurations_HydroBalanceSubperiodRepresentation.CHRONOLOGICAL_SUBPERIODS

    for (idx, h) in enumerate(hydro_unit_indexes)
        if hydro_unit_production_factor(inputs, h) == 0
            continue
        end
        marginal_cost_to_opportunity_cost =
            m3_per_second_to_hm3_per_hour() / hydro_unit_production_factor(inputs, h) / money_to_thousand_money()

        for blk in subperiods(inputs)
            hydro_opportunity_cost[blk, idx] = water_marginal_cost[blk, h] * marginal_cost_to_opportunity_cost
            downstream_idx = hydro_unit_turbine_to(inputs, h)
            if !is_null(downstream_idx) && downstream_idx in hydro_unit_indexes
                hydro_opportunity_cost[blk, idx] -=
                    water_marginal_cost[blk, downstream_idx] * marginal_cost_to_opportunity_cost
            end
        end
    end

    return hydro_opportunity_cost
end

function marginal_cost_to_opportunity_cost(
    inputs::Inputs,
    water_marginal_cost::AbstractArray{Float64, 1},
    hydro_unit_indexes::Vector{Int},
)
    hydro_opportunity_cost = zeros(number_of_subperiods(inputs), length(hydro_unit_indexes))

    @assert hydro_balance_subperiod_resolution(inputs) ==
            Configurations_HydroBalanceSubperiodRepresentation.AGGREGATED_SUBPERIODS

    for (idx, h) in enumerate(hydro_unit_indexes)
        if hydro_unit_production_factor(inputs, h) == 0
            continue
        end
        marginal_cost_to_opportunity_cost =
            m3_per_second_to_hm3_per_hour() / hydro_unit_production_factor(inputs, h) / money_to_thousand_money()

        for blk in subperiods(inputs)
            hydro_opportunity_cost[blk, idx] = water_marginal_cost[h] * marginal_cost_to_opportunity_cost
            downstream_idx = hydro_unit_turbine_to(inputs, h)
            if !is_null(downstream_idx) && downstream_idx in hydro_unit_indexes
                hydro_opportunity_cost[blk, idx] -=
                    water_marginal_cost[downstream_idx] * marginal_cost_to_opportunity_cost
            end
        end
    end

    return hydro_opportunity_cost
end
