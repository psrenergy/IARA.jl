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
    PlotRelationAll 

Type for plotting the relation between two agents in all scenarios.
"""
abstract type PlotRelationAll <: RelationPlotType end

"""
    PlotRelationMean

Type for plotting the relation between two agents in average across scenarios.
"""
abstract type PlotRelationMean <: RelationPlotType end

function plot_data(
    ::Type{PlotRelationAll},
    data_x::Array{Float32, N},
    data_y::Array{Float32, N},
    agent_x::String,
    agent_y::String,
    dimensions::Vector{String};
    title::String = "",
    x_label::String = "",
    y_label::String = "",
    unit_x::String = "",
    unit_y::String = "",
    flip_x::Bool = false,
    flip_y::Bool = false,
    trace_mode::String = "markers",
    file_path::String,
    initial_date::DateTime,
    period_type::Configurations_PeriodType.T,
    kwargs...,
) where {N}
    traces_x, trace_names_x = reshape_time_series!(PlotTimeSeriesAll, data_x, [agent_x], dimensions; kwargs...)
    traces_y, trace_names_y = reshape_time_series!(PlotTimeSeriesAll, data_y, [agent_y], dimensions; kwargs...)
    number_of_periods = size(traces_x, 2)
    number_of_traces = size(traces_x, 1)

    configs = Vector{Config}()

    title = title * " - All scenarios"
    for trace in 1:number_of_traces
        push!(
            configs,
            Config(;
                x = traces_x[trace, :],
                y = traces_y[trace, :],
                name = trace_names_x[trace],
                line = Dict("color" => get_plot_color(trace)),
                mode = trace_mode,
                # text = hover_ticks,
                hovertemplate = "$x_label %{x} $unit_x <br>$y_label %{y} $unit_y",
            ),
        )
    end

    main_configuration = Config(;
        title = title,
        xaxis = Dict(
            "title" => x_label,
            "autorange" => flip_x ? "reversed" : "normal",
        ),
        yaxis = Dict(
            "title" => y_label,
            "autorange" => flip_y ? "reversed" : "normal",
        ))

    if file_path == ""
        return Plot(configs, main_configuration)
    else
        _save_plot(Plot(configs, main_configuration), file_path * "_relation_all.html")
    end

    return
end

function plot_data(
    ::Type{PlotRelationMean},
    data_x::Array{Float32, N},
    data_y::Array{Float32, N},
    agent_x::String,
    agent_y::String,
    dimensions::Vector{String};
    title::String = "",
    x_label::String = "",
    y_label::String = "",
    unit_x::String = "",
    unit_y::String = "",
    flip_x::Bool = false,
    flip_y::Bool = false,
    trace_mode::String = "markers",
    file_path::String,
    initial_date::DateTime,
    period_type::Configurations_PeriodType.T,
    kwargs...,
) where {N}
    traces_x, _, trace_names_x, _ =
        reshape_time_series!(PlotTimeSeriesMean, data_x, [agent_x], dimensions; kwargs...)
    traces_y, _, trace_names_y, _ = reshape_time_series!(PlotTimeSeriesMean, data_y, [agent_y], dimensions; kwargs...)

    number_of_periods = size(traces_x, 2)
    number_of_traces = size(traces_x, 1)

    configs = Vector{Config}()

    title = title * " - Mean across scenarios"
    for trace in 1:number_of_traces
        push!(
            configs,
            Config(;
                x = traces_x[trace, :],
                y = traces_y[trace, :],
                name = trace_names_x[trace],
                line = Dict("color" => get_plot_color(trace)),
                mode = trace_mode,
                hovertemplate = "$x_label %{x} $unit_x <br>$y_label %{y} $unit_y",
            ))
    end

    main_configuration = Config(;
        title = title,
        xaxis = Dict(
            "title" => x_label * " [$unit_x]",
            "autorange" => flip_x ? "reversed" : "normal",
        ),
        yaxis = Dict(
            "title" => y_label * " [$unit_y]",
            "autorange" => flip_y ? "reversed" : "normal",
        ))

    if file_path == ""
        return Plot(configs, main_configuration)
    else
        _save_plot(Plot(configs, main_configuration), file_path * "_relation_avg.html")
    end

    return
end
