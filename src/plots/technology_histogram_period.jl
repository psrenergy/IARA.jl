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
    PlotTechnologyHistogramPeriod

Type for plotting a histogram where the observations are the total of generation for a technology at period i, considering all scenarios and subperiods.
"""
abstract type PlotTechnologyHistogramPeriod <: PlotType end

"""
    plot_data(::Type{PlotTechnologyHistogramPeriod}, data::Array{Float32, N}, agent_names::Vector{String}, dimensions::Vector{String}; title::String = "", unit::String = "", file_path::String, kwargs...)

Create a histogram plot for the total of generation for a technology at period i, considering all scenarios and subperiods.
"""
function plot_data(
    ::Type{PlotTechnologyHistogramPeriod},
    data::Array{Float32, N},
    agent_names::Vector{String},
    dimensions::Vector{String};
    title::String = "",
    unit::String = "",
    file_path::String,
    kwargs...,
) where {N}

    # observations are each scenario - subperiod for plant i in period j
    num_periods = size(data, 4)
    num_scenarios = size(data, 3)
    num_subperiods = size(data, 2)

    data_to_plot = Vector{Vector{Float64}}()
    for period in 1:num_periods
        data_for_period = Vector{Float64}()
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                push!(data_for_period, sum(data[:, subperiod, scenario, period]))
            end
        end
        push!(data_to_plot, data_for_period)
    end

    configs = Vector{Config}()
    for period in 1:num_periods
        push!(
            configs,
            Config(;
                x = data_to_plot[period],
                type = "histogram",
                name = "Period $period",
            ),
        )
    end

    main_configuration = Config(;
        title = title * " - Period",
        xaxis = Dict("title" => unit),
        yaxis = Dict("title" => "Frequency"),
    )

    if file_path == ""
        return Plot(configs, main_configuration)
    else
        _save_plot(Plot(configs, main_configuration), file_path * "_hist_period.html")
    end

    return
end
