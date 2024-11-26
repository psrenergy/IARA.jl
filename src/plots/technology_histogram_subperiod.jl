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
    PlotTechnologyHistogramSubperiod

Type for plotting a histogram where the observations are the total of generation for a technology at subperiod i, considering all scenarios and periods.
"""
abstract type PlotTechnologyHistogramSubperiod <: PlotType end

"""
    plot_data(::Type{PlotTechnologyHistogramSubperiod}, data::Array{Float32, N}, agent_names::Vector{String}, dimensions::Vector{String}; title::String = "", unit::String = "", file_path::String, kwargs...)

Create a histogram plot for the total of generation for a technology at subperiod i, considering all scenarios and periods.
"""
function plot_data(
    ::Type{PlotTechnologyHistogramSubperiod},
    data::Array{Float32, N},
    agent_names::Vector{String},
    dimensions::Vector{String};
    title::String = "",
    unit::String = "",
    file_path::String,
    initial_date::DateTime,
    period_type::Configurations_PeriodType.T,
) where {N}

    # observations are each scenario - period for plant i in subperiod j
    num_periods = size(data, 4)
    num_scenarios = size(data, 3)
    num_subperiods = size(data, 2)

    data_to_plot = Vector{Vector{Float64}}()
    for subperiod in 1:num_subperiods
        data_for_subperiod = Vector{Float64}()
        for scenario in 1:num_scenarios
            for period in 1:num_periods
                push!(data_for_subperiod, sum(data[:, subperiod, scenario, period]))
            end
        end
        push!(data_to_plot, data_for_subperiod)
    end

    plot_ref = plot()
    for subperiod in 1:num_subperiods
        plot_ref(;
            x = data_to_plot[subperiod],
            type = "histogram",
            name = "Subperiod $subperiod",
        )
    end

    plot_ref.layout.title.text = title * " - Subperiod"
    plot_ref.layout.xaxis.title = unit
    plot_ref.layout.yaxis.title = "Frequency"

    _save_plot(plot_ref, file_path * "_hist_subperiod.html")

    return
end
