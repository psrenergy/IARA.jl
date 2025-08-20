#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

"""
    generate_inflow_scenarios(inputs::Inputs)

Generate inflow scenarios for the optimization problem.
"""
function generate_inflow_scenarios(inputs::Inputs)
    # Fit and simulate PAR(p)
    incremental_inflow = calculate_incremental_inflow(inputs, gauging_station_historical_inflow(inputs))
    parp_models = PARp.(incremental_inflow, periods_per_year(inputs), parp_max_lags(inputs))
    fit_par!.(parp_models)
    inflow, noise = simulate_par(
        parp_models,
        number_of_periods(inputs),
        number_of_scenarios(inputs);
        lognormal_noise = false,
        return_noise = true,
    )
    # inflow and noise have dimensions (number_of_periods(inputs), number_of_gauging_stations, number_of_scenarios(inputs))
    inflow = permutedims(inflow, [2, 3, 1])
    noise = permutedims(noise, [2, 3, 1])

    # Save outputs
    gauging_stations = index_of_elements(inputs, GaugingStation)
    number_of_gauging_stations = number_of_elements(inputs, GaugingStation)

    parp_coefficients = zeros(number_of_gauging_stations, parp_max_lags(inputs), periods_per_year(inputs))
    inflow_period_average = zeros(number_of_gauging_stations, periods_per_year(inputs))
    inflow_period_std_dev = zeros(number_of_gauging_stations, periods_per_year(inputs))
    for gauging_station in gauging_stations, period in 1:periods_per_year(inputs)
        coefficients = parp_models[gauging_station].best_AR_stage[period].ϕ
        for (i, coefficient) in enumerate(coefficients)
            parp_coefficients[gauging_station, i, period] = coefficient
        end
        inflow_period_average[gauging_station, period] = parp_models[gauging_station].μ_stage[period]
        inflow_period_std_dev[gauging_station, period] = parp_models[gauging_station].σ_stage[period]
    end

    write_parp_outputs(inputs, inflow, noise, parp_coefficients, inflow_period_average, inflow_period_std_dev)

    return nothing
end

"""
    write_parp_outputs(
        inputs::Inputs,
        inflow::Array{Float64, 3},
        noise::Array{Float64, 3},
        parp_coefficients::Array{Float64, 3},
        inflow_period_average::Array{Float64, 2},
        inflow_period_std_dev::Array{Float64, 2},
    )

Write PAR(p) outputs to files.
"""
function write_parp_outputs(inputs::Inputs,
    inflow::Array{Float64, 3},
    noise::Array{Float64, 3},
    parp_coefficients::Array{Float64, 3},
    inflow_period_average::Array{Float64, 2},
    inflow_period_std_dev::Array{Float64, 2},
)
    if !isdir(path_parp(inputs))
        mkdir(path_parp(inputs))
    end
    write_timeseries_file(
        joinpath(path_parp(inputs), gauging_station_inflow_file(inputs)),
        inflow;
        dimensions = ["period", "scenario"],
        labels = gauging_station_label(inputs),
        time_dimension = "period",
        dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs)],
        initial_date = initial_date_time(inputs),
        unit = "m3/s",
    )
    write_timeseries_file(
        joinpath(path_parp(inputs), gauging_station_inflow_noise_file(inputs)),
        noise;
        dimensions = ["period", "scenario"],
        labels = gauging_station_label(inputs),
        time_dimension = "period",
        dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs)],
        initial_date = initial_date_time(inputs),
        unit = "m3/s",
    )
    write_timeseries_file(
        joinpath(path_parp(inputs), gauging_station_parp_coefficients_file(inputs)),
        parp_coefficients;
        dimensions = ["inflow_period", "lag"],
        labels = gauging_station_label(inputs),
        time_dimension = "inflow_period",
        dimension_size = [periods_per_year(inputs), parp_max_lags(inputs)],
        initial_date = initial_date_time(inputs),
        unit = "-",
    )
    write_timeseries_file(
        joinpath(path_parp(inputs), gauging_station_inflow_period_average_file(inputs)),
        inflow_period_average;
        dimensions = ["inflow_period"],
        labels = gauging_station_label(inputs),
        time_dimension = "inflow_period",
        dimension_size = [periods_per_year(inputs)],
        initial_date = initial_date_time(inputs),
        unit = "m3/s",
    )
    write_timeseries_file(
        joinpath(path_parp(inputs), gauging_station_inflow_period_std_dev_file(inputs)),
        inflow_period_std_dev;
        dimensions = ["inflow_period"],
        labels = gauging_station_label(inputs),
        time_dimension = "inflow_period",
        dimension_size = [periods_per_year(inputs)],
        initial_date = initial_date_time(inputs),
        unit = "m3/s",
    )
    return nothing
end

"""
    calculate_incremental_inflow(inputs::Inputs, total_inflow::Vector{Vector{Float64}})

Calculate incremental inflow from total inflow.
"""
function calculate_incremental_inflow(inputs::Inputs, total_inflow::Vector{Vector{Float64}})
    incremental_inflow = deepcopy(total_inflow)
    gauging_stations = index_of_elements(inputs, GaugingStation)

    # Reverse downstream relation
    upstream_stations = [Int[] for _ in gauging_stations]
    for station in gauging_stations
        downstream_station = gauging_station_downstream_index(inputs, station)
        if is_null(downstream_station)
            continue
        end
        push!(upstream_stations[downstream_station], station)
    end

    # Calculate incremental inflow
    for station in gauging_stations
        for upstream_station in upstream_stations[station]
            incremental_inflow[station] .-= total_inflow[upstream_station]
        end
    end

    return incremental_inflow
end
