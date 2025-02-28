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
    GaugingStation

Collection representing the gauging stations in the system.
"""
@collection @kwdef mutable struct GaugingStation <: AbstractCollection
    label::Vector{String} = []
    # index of the gauging station which is downstream from the gauinging station at index i
    downstream_index::Vector{Int} = []
    historical_inflow::Vector{Vector{Float64}} = Vector{Vector{Float64}}()
    inflow_initial_state::Matrix{Float64} = Matrix{Float64}(undef, 0, 0)
end

# ---------------------------------------------------------------------
# Collection manipulation
# ---------------------------------------------------------------------

"""
    initialize!(gauging_station::GaugingStation, inputs::AbstractInputs)

Initialize the GaugingStation collection from the database.
"""
function initialize!(gauging_station::GaugingStation, inputs::AbstractInputs)
    num_gauging_stations = PSRI.max_elements(inputs.db, "GaugingStation")
    if num_gauging_stations == 0
        return nothing
    end

    gauging_station.label = PSRI.get_parms(inputs.db, "GaugingStation", "label")
    gauging_station.downstream_index = PSRI.get_map(inputs.db, "GaugingStation", "GaugingStation", "downstream")

    if read_inflow_from_file(inputs)
        return nothing
    end

    gauging_station.historical_inflow = Vector{Vector{Float64}}(undef, num_gauging_stations)
    for (idx, label) in enumerate(gauging_station.label)
        gauging_station.historical_inflow[idx] =
            PSRDatabaseSQLite.read_time_series_table(
                inputs.db,
                "GaugingStation",
                "historical_inflow",
                label,
            ).historical_inflow
    end

    if any(isempty.(gauging_station.historical_inflow))
        # TODO: How to add in validation?
        @error("Inflow is set to use the PAR(p) model, but GaugingStation historical inflow data is missing.")
    end

    # Get the last 'parp_max_lags' inflow values for each gauging station
    gauging_station.inflow_initial_state = zeros(num_gauging_stations, parp_max_lags(inputs))
    for (idx, inflow_vector) in enumerate(gauging_station.historical_inflow)
        gauging_station.inflow_initial_state[idx, :] = inflow_vector[end-parp_max_lags(inputs)+1:end]
    end

    update_time_series_from_db!(gauging_station, inputs.db, initial_date_time(inputs))

    return nothing
end

function update_time_series_from_db!(
    gauging_station::GaugingStation,
    db::DatabaseSQLite,
    period_date_time::DateTime,
)
    return nothing
end

"""
    add_gauging_station!(db::DatabaseSQLite; kwargs...)

Add a Gauging Station to the database.

Required arguments:

  - `label::String`: Hydro Unit label.
  - `inflow::DataFrames.DataFrame`: A dataframe containing time series attributes (described below).

Optional arguments:

  - `gaugingstation_downstream::String`: Downstream gauging station label (only if the Gauging Station already exists).

--- 

**Time Series inflow**

The `inflow` dataframe has columns that may be mandatory or not, depending on some configurations about the case.


Required columns
  - `date_time::Vector{DateTime}`: date and time of the time series data.
  - `historical_inflow::Vector{Float64}`: Historical inflow data. `[hm³/s]`
    - _Mandatory if_ `Configuration.inflow_scenarios_files` _is set to_ `NONE`

Example:
```julia
IARA.add_gauging_station!(db;
    label = "gauging_station",
)
```
"""
function add_gauging_station!(db::DatabaseSQLite; kwargs...)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    PSRI.create_element!(db, "GaugingStation"; sql_typed_kwargs...)
    return nothing
end

"""
    update_gauging_station!(db::DatabaseSQLite, label::String; kwargs...)

Update the GaugingStation named 'label' in the database.
"""
function update_gauging_station!(
    db::DatabaseSQLite,
    label::String;
    kwargs...,
)
    sql_typed_kwargs = build_sql_typed_kwargs(kwargs)
    for (attribute, value) in sql_typed_kwargs
        PSRI.set_parm!(
            db,
            "GaugingStation",
            string(attribute),
            label,
            value,
        )
    end
    return db
end

"""
    update_gauging_station_relation!(db::DatabaseSQLite, label::String; collection::String, relation_type::String, related_label::String)

Update the relation of the GaugingStation named 'label' in the database.
"""
function update_gauging_station_relation!(
    db::DatabaseSQLite,
    gauging_station_label::String;
    collection::String,
    relation_type::String,
    related_label::String,
)
    PSRI.set_related!(
        db,
        "GaugingStation",
        collection,
        gauging_station_label,
        related_label,
        relation_type,
    )
    return db
end

"""
    validate(gauging_station::GaugingStation)

Validate the gauging station collection.
"""
function validate(gauging_station::GaugingStation)
    num_errors = 0
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, gauging_station::GaugingStation)

Validate the GaugingStation within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, gauging_station::GaugingStation)
    num_errors = 0
    return num_errors
end

# ---------------------------------------------------------------------
# Collection getters
# ---------------------------------------------------------------------

function normalized_initial_inflow(inputs, period_idx::Integer, h::Integer, tau::Integer)
    gauging_station_idx = hydro_unit_gauging_station_index(inputs, h)
    if time_series_inflow_period_std_dev(inputs)[gauging_station_idx, period_idx] == 0
        return 0.0
    else
        return (
            gauging_station_inflow_initial_state(inputs)[gauging_station_idx, tau] -
            time_series_inflow_period_average(inputs)[gauging_station_idx, period_idx]
        ) / time_series_inflow_period_std_dev(inputs)[gauging_station_idx, period_idx]
    end
end

"""
    gauging_station_inflow_file(inputs::AbstractInputs)

Return the inflow time series file for all gauging stations.
"""
gauging_station_inflow_file(inputs::AbstractInputs) = "inflow"

"""
    gauging_station_inflow_noise_file(inputs::AbstractInputs)

Return the inflow noise time series file for all gauging stations.
"""
gauging_station_inflow_noise_file(inputs::AbstractInputs) = "inflow_noise"

"""
    gauging_station_parp_coefficients_file(inputs::AbstractInputs)

Return the PAR(p) coefficients time series file for all gauging stations.
"""
gauging_station_parp_coefficients_file(inputs::AbstractInputs) = "parp_coefficients"
gauging_station_parp_coefficients_file() = "parp_coefficients"

"""
    gauging_station_inflow_period_average_file(inputs::AbstractInputs)

Return the period average inflow time series file for all gauging stations.
"""
gauging_station_inflow_period_average_file(inputs::AbstractInputs) = "inflow_period_average"
gauging_station_inflow_period_average_file() = "inflow_period_average"

"""
    gauging_station_inflow_period_std_dev_file(inputs::AbstractInputs)

Return the period standard deviation inflow time series file for all gauging stations.
"""
gauging_station_inflow_period_std_dev_file(inputs::AbstractInputs) = "inflow_period_std_dev"
gauging_station_inflow_period_std_dev_file() = "inflow_period_std_dev"
