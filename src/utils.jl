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
    date_time = date_time_from_period(inputs, period)
    if time_series_step(inputs) == Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
        return Dates.month(date_time)
    else
        error("Time series step $(time_series_step(inputs)) not supported.")
    end
end

function get_lower_bound(inputs::Inputs, run_time_options::RunTimeOptions)
    if run_mode(inputs) == RunMode.PRICE_TAKER_BID
        max_price = get_max_price(inputs)
        max_generation = 0.0
        for h in index_of_elements(inputs, HydroUnit; run_time_options)
            max_generation += hydro_unit_max_generation(inputs, h)
        end
        for t in index_of_elements(inputs, ThermalUnit; run_time_options)
            max_generation += thermal_unit_max_generation(inputs, t)
        end
        for r in index_of_elements(inputs, RenewableUnit; run_time_options)
            max_generation += renewable_unit_max_generation(inputs, r)
        end
        lower_bound =
            -max_price * max_generation * sum(subperiod_duration_in_hours(inputs))
        return lower_bound
    elseif run_mode(inputs) == RunMode.STRATEGIC_BID
        @warn "Strategic Bid lower bound not implemented."
        return 0.0
    else
        return 0.0
    end
end

function get_max_price(inputs::Inputs)
    spot_price_file = joinpath(path_case(inputs), "load_marginal_cost")
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

All time series file need to be a CSV file, accompanied by a .toml file with the same name.

Each collection in the database can be linked to different time series files.

The possible files for each collection are:

$(PSRDatabaseSQLite.time_series_files_docstrings(model_directory()))

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
