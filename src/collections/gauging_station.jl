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
    inflow_initial_state_variation_type::Vector{GaugingStation_InflowInitialStateVariationType.T} = []

    inflow_noise_ex_ante_file::String = ""
    inflow_noise_ex_post_file::String = ""
    parp_coefficients_file::String = ""
    inflow_period_average_file::String = ""
    inflow_period_std_dev_file::String = ""
    inflow_initial_state_by_scenario_file::String = ""
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

    gauging_station.inflow_initial_state_variation_type =
        convert_to_enum.(
            PSRI.get_parms(inputs.db, "GaugingStation", "inflow_initial_state_variation_type"),
            GaugingStation_InflowInitialStateVariationType.T,
        )
    gauging_station.inflow_initial_state_by_scenario_file =
        PSRDatabaseSQLite.read_time_series_file(inputs.db, "GaugingStation", "inflow_initial_state_by_scenario")

    if fit_parp_model(inputs)
        # When fitting the PAR(p) model, these files are output files, so we use the IARA standard.
        gauging_station.inflow_noise_ex_ante_file = "inflow_noise_ex_ante"
        gauging_station.inflow_noise_ex_post_file = "inflow_noise_ex_post"
        gauging_station.parp_coefficients_file = "parp_coefficients"
        gauging_station.inflow_period_average_file = "inflow_period_average"
        gauging_station.inflow_period_std_dev_file = "inflow_period_std_dev"
    else
        # When reading the coefficients, these are input files with user-defined names
        gauging_station.inflow_noise_ex_ante_file =
            PSRDatabaseSQLite.read_time_series_file(inputs.db, "GaugingStation", "inflow_noise_ex_ante")
        gauging_station.inflow_noise_ex_post_file =
            PSRDatabaseSQLite.read_time_series_file(inputs.db, "GaugingStation", "inflow_noise_ex_post")
        gauging_station.parp_coefficients_file =
            PSRDatabaseSQLite.read_time_series_file(inputs.db, "GaugingStation", "parp_coefficients")
        gauging_station.inflow_period_average_file =
            PSRDatabaseSQLite.read_time_series_file(inputs.db, "GaugingStation", "inflow_period_average")
        gauging_station.inflow_period_std_dev_file =
            PSRDatabaseSQLite.read_time_series_file(inputs.db, "GaugingStation", "inflow_period_std_dev")
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

    if any(isempty.(gauging_station.historical_inflow)) ||
       any(length.(gauging_station.historical_inflow) .< parp_max_lags(inputs))
        # If it reaches here, it's an error.
        # This will be brought in validation
        return nothing
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

$(PSRDatabaseSQLite.collection_docstring(model_directory(), "GaugingStation"))

!!! note "Note"
    - `historical_inflow` is required if `Configuration.inflow_scenarios_files` _is set to_ `FIT_PARP_MODEL_FROM_DATA`

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
    if any(
        gauging_station.inflow_initial_state_variation_type .==
        GaugingStation_InflowInitialStateVariationType.BY_SCENARIO,
    ) && isempty(gauging_station.inflow_initial_state_by_scenario_file)
        @error(
            "At least one Gauging Station has inflow initial state variation type set to `BY_SCENARIO`, but no inflow initial state by scenario file was linked."
        )
        num_errors += 1
    end
    return num_errors
end

"""
    advanced_validations(inputs::AbstractInputs, gauging_station::GaugingStation)

Validate the GaugingStation within the inputs context. Return the number of errors found.
"""
function advanced_validations(inputs::AbstractInputs, gauging_station::GaugingStation)
    num_errors = 0
    if fit_parp_model(inputs) || (
        read_parp_coefficients(inputs) && any(
            gauging_station_inflow_initial_state_variation_type(inputs) .==
            GaugingStation_InflowInitialStateVariationType.CONSTANT_VALUE,
        )
    )
        if any(isempty.(gauging_station.historical_inflow))
            @error("Inflow is set to use fit a PAR(p) model, but GaugingStation historical inflow data is missing.")
            num_errors += 1
        end
        for i in 1:length(gauging_station.historical_inflow)
            if length(gauging_station.historical_inflow[i]) < parp_max_lags(inputs)
                @error(
                    "There isn't enough historical inflow in GaugingStation $(gauging_station.label[i]) data for the PAR(p) model.
             Expected at least $(parp_max_lags(inputs)) values, but got $(length(gauging_station.historical_inflow[i]))."
                )
                num_errors += 1
            end
        end
    end
    if read_parp_coefficients(inputs)
        if read_ex_post_inflow_file(inputs) && gauging_station.inflow_noise_ex_post_file == ""
            @error(
                "Defining the ex-post inflow noise file name is required when reading PAR(p) coefficients and using the ex-post file."
            )
            num_errors += 1
        end
        if read_ex_ante_inflow_file(inputs) && gauging_station.inflow_noise_ex_ante_file == ""
            @error(
                "Defining the ex-ante inflow noise file name is required when reading PAR(p) coefficients and using the ex-ante file."
            )
            num_errors += 1
        end
        if gauging_station.parp_coefficients_file == ""
            @error("Defining the PAR(p) coefficients file name is required when reading PAR(p) coefficients.")
            num_errors += 1
        end
        if gauging_station.inflow_period_average_file == ""
            @error("Defining the inflow period average file name is required when reading PAR(p) coefficients.")
            num_errors += 1
        end
        if gauging_station.inflow_period_std_dev_file == ""
            @error(
                "Defining the inflow period standard deviation file name is required when reading PAR(p) coefficients."
            )
            num_errors += 1
        end
    end
    return num_errors
end

function normalized_initial_inflow(inputs, period_idx::Integer, h::Integer, tau::Integer)
    gauging_station_idx = hydro_unit_gauging_station_index(inputs, h)
    if time_series_inflow_period_std_dev(inputs)[gauging_station_idx, period_idx] == 0
        return 0.0
    else
        inflow_initial_state =
            if gauging_station_inflow_initial_state_variation_type(inputs, gauging_station_idx) ==
               GaugingStation_InflowInitialStateVariationType.BY_SCENARIO
                inputs.time_series.inflow_initial_state_by_scenario[gauging_station_idx, tau]
            else
                gauging_station_inflow_initial_state(inputs)[gauging_station_idx, tau]
            end
        return (
            inflow_initial_state -
            time_series_inflow_period_average(inputs)[gauging_station_idx, period_idx]
        ) / time_series_inflow_period_std_dev(inputs)[gauging_station_idx, period_idx]
    end
end

"""
    some_inflow_initial_state_varies_by_scenario(inputs::AbstractInputs)

Check if it is necessary to read the inflow initial state by scenario timeseries file.
"""
some_inflow_initial_state_varies_by_scenario(inputs::AbstractInputs) =
    any(
        gauging_station_inflow_initial_state_variation_type(inputs) .==
        GaugingStation_InflowInitialStateVariationType.BY_SCENARIO,
    )

"""
    gauging_station_inflow_file(inputs::AbstractInputs)

Return the inflow time series file for all gauging stations.
"""
gauging_station_inflow_file(inputs::AbstractInputs) = "inflow"

"""
    normalized_inflow_from_previous_period(inputs::AbstractInputs, run_time_options, period::Int, scenario::Int)

Get the normalized inflow state variables from the previous period for PAR(p) model.

If the period is the first one, the initial state is returned. Otherwise, it is read from the serialized results of the previous stage.
"""
function normalized_inflow_from_previous_period(inputs::AbstractInputs, run_time_options, period::Int, scenario::Int)
    num_hydro_units = number_of_elements(inputs, HydroUnit; run_time_options)
    existing_hydro_units = index_of_elements(inputs, HydroUnit; run_time_options, filters = [is_existing])
    previous_normalized_inflow = zeros(Float64, num_hydro_units, parp_max_lags(inputs))

    # Always initialize with the initial state
    for h in existing_hydro_units, tau in 1:parp_max_lags(inputs)
        period_idx = if cyclic_policy_graph(inputs)
            # In cyclic graphs, we consider all lags are from the same season as the first period
            consult_period_season_map(inputs; period = 1, scenario, index = 1)
        else
            # Non-cyclic graphs, use the default calculation
            mod1(period_index_in_year(inputs, tau) - parp_max_lags(inputs), periods_per_year(inputs))
        end
        previous_normalized_inflow[h, tau] = normalized_initial_inflow(inputs, period_idx, h, tau)
    end

    if period != 1
        # Read from serialized results
        if is_nash_equilibrium_initialization(run_time_options)
            error("Nash equilibrium initialization not yet supported for PAR(p) model.")
        else
            normalized_inflow_state = read_serialized_clearing_variable(
                inputs,
                RunTime_ClearingSubproblem.EX_POST_PHYSICAL,
                :normalized_inflow;
                period = period - 1,
                scenario = scenario,
            )
            # Update with the values from the previous period
            for h in axes(normalized_inflow_state, 1), tau in axes(normalized_inflow_state, 2)
                previous_normalized_inflow[h, tau] = normalized_inflow_state[h, tau].out
            end
        end
    end
    return previous_normalized_inflow
end
