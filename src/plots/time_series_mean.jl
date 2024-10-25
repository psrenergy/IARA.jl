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
    PlotTimeSeriesMean

Type for a time series plot with the mean of scenarios, with a confidence interval of 95%.
"""
abstract type PlotTimeSeriesMean <: PlotType end

function agent_mean_and_sd_in_scenarios(
    ::Type{PlotTimeSeriesMean},
    data::Array{Float64, 3},
    agent_names::Vector{String};
    kwargs...,
)
    reshaped_data = dropdims(mean(data; dims = 2); dims = 2)
    standard_deviation = dropdims(std(data; dims = 2); dims = 2)
    return reshaped_data, standard_deviation, agent_names
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesMean},
    data::Array{Float32, 3},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    num_scenarios = size(data, 2)
    time_series, standard_dev, trace_names =
        agent_mean_and_sd_in_scenarios(PlotTimeSeriesMean, data, agent_names; kwargs...)
    return time_series, standard_dev, trace_names, num_scenarios
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesMean},
    data::Array{Float32, 4},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    if !("subperiod" in dimensions) && ("bid_segment" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
        num_scenarios = size(time_series, 2)
        time_series, standard_dev, trace_names =
            agent_mean_and_sd_in_scenarios(PlotTimeSeriesMean, time_series, agent_names; kwargs...)
        return time_series, standard_dev, trace_names, num_scenarios
    elseif ("subperiod" in dimensions) && !("bid_segment" in dimensions)
        time_series = merge_period_subperiod(data)
        num_scenarios = size(time_series, 2)
        time_series, standard_dev, trace_names =
            agent_mean_and_sd_in_scenarios(PlotTimeSeriesMean, time_series, agent_names; kwargs...)
        return time_series, standard_dev, trace_names, num_scenarios
    else
        error(
            "A time series output with 4 dimensions should have either 'bid_segment' or 'subperiod' as a dimension.",
        )
    end
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesMean},
    data::Array{Float32, 5},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    if !("subscenario" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
        time_series = merge_period_subperiod(time_series)
        num_scenarios = size(time_series, 2)
        time_series, standard_dev, agent_names =
            agent_mean_and_sd_in_scenarios(PlotTimeSeriesMean, time_series, agent_names; kwargs...)
        return time_series, standard_dev, agent_names, num_scenarios
    elseif !("bid_segment" in dimensions)
        time_series = merge_period_subperiod(data)
        time_series, modified_scenario_names =
            merge_scenario_subscenario(time_series, agent_names; kwargs...)
        num_scenarios = size(time_series, 2)
        time_series, standard_dev, modified_agent_names =
            agent_mean_and_sd_in_scenarios(PlotTimeSeriesMean, time_series, agent_names; kwargs...)
        return time_series, standard_dev, modified_agent_names, num_scenarios
    elseif !("subperiod" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
        time_series, modified_scenario_names =
            merge_scenario_subscenario(time_series, agent_names; kwargs...)
        num_scenarios = size(time_series, 2)
        time_series, standard_dev, modified_agent_names =
            agent_mean_and_sd_in_scenarios(PlotTimeSeriesMean, time_series, agent_names; kwargs...)
        return time_series, standard_dev, modified_agent_names, num_scenarios
    else
        error(
            "A time series output with 5 dimensions should have either 'bid_segment' or 'subscenario' as a dimension.",
        )
    end
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesMean},
    data::Array{Float32, 6},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
    time_series = merge_period_subperiod(time_series)
    time_series, modified_scenario_names = merge_scenario_subscenario(time_series, agent_names; kwargs...)
    num_scenarios = size(time_series, 2)
    time_series, standard_dev, modified_agent_names =
        agent_mean_and_sd_in_scenarios(PlotTimeSeriesMean, time_series, agent_names; kwargs...)
    return time_series, standard_dev, modified_agent_names, num_scenarios
end

function plot_data(
    ::Type{PlotTimeSeriesMean},
    data::Array{Float32, N},
    agent_names::Vector{String},
    dimensions::Vector{String};
    title::String = "",
    unit::String = "",
    file_path::String,
    initial_date::DateTime,
    period_type::Configurations_PeriodType.T,
    kwargs...,
) where {N}
    traces, standard_dev, trace_names, number_of_scenarios =
        reshape_time_series!(PlotTimeSeriesMean, data, agent_names, dimensions; kwargs...)

    number_of_periods = size(traces, 2)
    number_of_traces = size(traces, 1)

    initial_number_of_periods = size(data, N)
    plot_ticks, hover_ticks = get_plot_ticks(traces, initial_number_of_periods, initial_date, period_type)

    confidence_interval_top = Vector{Vector{Float64}}()
    confidence_interval_bottom = Vector{Vector{Float64}}()
    for trace in 1:number_of_traces
        confidence_top = Vector{Float64}()
        confidence_bottom = Vector{Float64}()
        for i in 1:number_of_periods
            # 95 % confidence interval
            push!(confidence_top, traces[trace, i] + 1.96 * standard_dev[trace, i] / sqrt(number_of_scenarios))
            push!(confidence_bottom, traces[trace, i] - 1.96 * standard_dev[trace, i] / sqrt(number_of_scenarios))
        end
        push!(confidence_interval_top, confidence_top)
        push!(confidence_interval_bottom, confidence_bottom)
    end

    plot_type = ifelse(number_of_periods == 1, "bar", "line")

    configs = Vector{Config}()

    title = title * " - Mean across scenarios"
    for trace in 1:number_of_traces
        push!(
            configs,
            Config(;
                x = 1:number_of_periods,
                y = confidence_interval_top[trace],
                mode = "lines",
                showlegend = false,
                legendgroup = trace_names[trace],
                line = Dict("color" => get_plot_color(trace; transparent = true)),
                type = "scatter",
            ))
        push!(
            configs,
            Config(;
                x = 1:number_of_periods,
                y = confidence_interval_bottom[trace],
                fill = "tonexty",
                mode = "lines",
                name = trace_names[trace] * " (95% CI)",
                legendgroup = trace_names[trace],
                line = Dict("color" => get_plot_color(trace; transparent = true)),
            ))
        push!(
            configs,
            Config(;
                x = 1:number_of_periods,
                y = traces[trace, :],
                name = trace_names[trace],
                legendgroup = trace_names[trace],
                line = Dict("color" => get_plot_color(trace)),
                type = plot_type,
                text = hover_ticks,
                hovertemplate = "%{y} $unit<br>%{text}",
            ))
    end

    main_configuration = Config(;
        title = title,
        xaxis = Dict(
            "title" => "Period",
            "tickmode" => "array",
            "tickvals" => [i for i in eachindex(plot_ticks)],
            "ticktext" => plot_ticks,
        ),
        yaxis = Dict("title" => unit),
    )

    if file_path == ""
        return Plot(configs, main_configuration)
    else
        _save_plot(Plot(configs, main_configuration), file_path * "_avg.html")
    end

    return
end
