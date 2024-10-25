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
    PlotTechnologyHistogram

Type for plotting a histogram where the observations are the total of generation for a technology, considering all scenarios, periods and subperiods.
"""
abstract type PlotTechnologyHistogram <: PlotType end

function plot_data(
    ::Type{PlotTechnologyHistogram},
    data::Array{Float32, N},
    agent_names::Vector{String},
    dimensions::Vector{String};
    title::String = "",
    unit::String = "",
    file_path::String,
    kwargs...,
) where {N}

    # observations are each scenario - subperiod for plant i
    num_periods = size(data, 4)
    num_scenarios = size(data, 3)
    num_subperiods = size(data, 2)

    data_to_plot = Vector{Float64}()
    for scenario in 1:num_scenarios
        for subperiod in 1:num_subperiods
            for period in 1:num_periods
                push!(data_to_plot, sum(data[:, subperiod, scenario, period]))
            end
        end
    end

    config = Config(;
        x = data_to_plot,
        type = "histogram",
    )

    main_configuration = Config(;
        title = title * " - Scenario - Subperiod",
        xaxis = Dict("title" => unit),
        yaxis = Dict("title" => "Frequency"),
    )

    if file_path == ""
        return Plot(config, main_configuration)
    else
        _save_plot(Plot(config, main_configuration), file_path * "_hist.html")
    end

    return
end
