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
    PlotTechnologyHistogramPeriodSubperiod

Type for plotting a histogram where the observations are the total of generation for a technology at subperiod i, period j, considering all scenarios.
"""
abstract type PlotTechnologyHistogramPeriodSubperiod <: PlotType end

"""
    plot_data(
        ::Type{PlotTechnologyHistogramPeriodSubperiod},
        data::Array{Float32, N},
        agent_names::Vector{String},
        dimensions::Vector{String};
        title::String,
        unit::String,
        file_path::String,
        kwargs...,
    ) where {N}


Plots a histogram where the observations are the total of generation for a technology at subperiod i, period j, considering all scenarios.
"""
function plot_data(
    ::Type{PlotTechnologyHistogramPeriodSubperiod},
    data::Array{Float32, N},
    agent_names::Vector{String},
    dimensions::Vector{String};
    title::String = "",
    unit::String = "",
    file_path::String,
    kwargs...,
) where {N}

    # observations are each scenario for plant i in subperiod - period j
    num_periods = size(data, 4)
    num_scenarios = size(data, 3)
    num_subperiods = size(data, 2)

    data_to_plot = Vector{Vector{Float64}}()
    for period in 1:num_periods
        for subperiod in 1:num_subperiods
            data_for_period_subperiod = Vector{Float64}()
            for scenario in 1:num_scenarios
                push!(data_for_period_subperiod, sum(data[:, subperiod, scenario, period]))
            end
            push!(data_to_plot, data_for_period_subperiod)
        end
    end

    configs = Vector{Config}()
    for period in 1:num_periods
        for subperiod in 1:num_subperiods
            push!(
                configs,
                Config(;
                    x = data_to_plot[subperiod],
                    type = "histogram",
                    name = "Subperiod $subperiod - Period $period",
                ),
            )
        end
    end

    main_configuration = Config(;
        title = title * " - Period - Subperiod",
        xaxis = Dict("title" => unit),
        yaxis = Dict("title" => "Frequency"),
    )

    if file_path == ""
        return Plot(configs, main_configuration)
    else
        _save_plot(Plot(configs, main_configuration), file_path * "_hist_period_subperiod.html")
    end

    return
end
