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
    PlotTimeSeriesQuantiles

Type for a time series plot with P10, P50, and P90 quantiles of scenarios.
"""
abstract type PlotTimeSeriesQuantiles <: PlotType end

function agent_quantile_in_scenarios(
    ::Type{PlotTimeSeriesQuantiles},
    data::Array{Float64, 3},
    agent_names::Vector{String};
    kwargs...,
)
    num_periods = size(data, 3)
    num_agents = size(data, 1)

    reshaped_data = Array{Float64, 2}(undef, 3 * num_agents, num_periods)
    for agent in 1:num_agents
        p10_idx = agent
        p50_idx = num_agents + agent
        p90_idx = 2 * num_agents + agent
        all_agent_indexes = [p10_idx, p50_idx, p90_idx]
        for period in 1:num_periods
            reshaped_data[all_agent_indexes, period] =
                quantile(data[agent, :, period], [0.1, 0.5, 0.9])
        end
    end
    return reshaped_data, agent_names
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesQuantiles},
    data::Array{Float32, 3},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    time_series, agent_names = agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, data, agent_names; kwargs...)
    return time_series, agent_names
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesQuantiles},
    data::Array{Float32, 4},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    if !("subperiod" in dimensions) && ("bid_segment" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
        time_series, agent_names =
            agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names; kwargs...)
        return time_series, agent_names
    elseif ("subperiod" in dimensions) && !("bid_segment" in dimensions)
        time_series = merge_period_subperiod(data)
        time_series, agent_names =
            agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names; kwargs...)
        return time_series, agent_names
    else
        error(
            "A time series output with 4 dimensions should have either 'bid_segment' or 'subperiod' as a dimension.",
        )
    end
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesQuantiles},
    data::Array{Float32, 5},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    if !("subscenario" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
        time_series = merge_period_subperiod(time_series)
        time_series, agent_names =
            agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names; kwargs...)
        return time_series, agent_names
    elseif !("bid_segment" in dimensions)
        time_series = merge_period_subperiod(data)
        time_series, modified_scenario_names =
            merge_scenario_subscenario(time_series, agent_names; kwargs...)
        time_series, modified_agent_names =
            agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names; kwargs...)
        return time_series, modified_agent_names
    elseif !("subperiod" in dimensions)
        time_series, modified_names = merge_segment_agent(data, agent_names; kwargs...)
        time_series, modified_scenario_names =
            merge_scenario_subscenario(time_series, modified_names; kwargs...)
        time_series, modified_agent_names =
            agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, modified_names; kwargs...)
        return time_series, modified_agent_names
    else
        error(
            "A time series output with 5 dimensions should have either 'bid_segment' or 'subscenario' as a dimension.",
        )
    end
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesQuantiles},
    data::Array{Float32, 6},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
    time_series = merge_period_subperiod(time_series)
    time_series, modified_scenario_names = merge_scenario_subscenario(time_series, agent_names; kwargs...)
    time_series, modified_agent_names =
        agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names; kwargs...)
    return time_series, modified_agent_names
end

function plot_data(
    ::Type{PlotTimeSeriesQuantiles},
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
    traces, trace_names = reshape_time_series!(PlotTimeSeriesQuantiles, data, agent_names, dimensions; kwargs...)
    number_of_periods = size(traces, 2)
    number_of_agents = length(trace_names)

    initial_number_of_periods = size(data, N)
    plot_ticks, hover_ticks = get_plot_ticks(traces, initial_number_of_periods, initial_date, period_type)
    plot_type = ifelse(number_of_periods == 1, "bar", "line")

    configs = Vector{Config}()

    title = title * " - Scenario quantiles"
    for agent in 1:number_of_agents
        p10_idx = agent
        p50_idx = number_of_agents + agent
        p90_idx = 2 * number_of_agents + agent
        push!(configs,
            Config(;
                x = vcat(1:number_of_periods, number_of_periods:-1:1),
                y = vcat(traces[p10_idx, :], reverse(traces[p90_idx, :])),
                name = trace_names[agent] * " (P10 - P90)",
                fill = "toself",
                line = Dict("color" => "transparent"),
                fillcolor = get_plot_color(agent; transparent = true),
                type = plot_type,
                text = hover_ticks,
                hovertemplate = "%{y} $unit",
                hovermode = "closest",
            ))
        push!(configs,
            Config(;
                x = 1:number_of_periods,
                y = traces[p50_idx, :],
                name = trace_names[agent] * " (P50)",
                line = Dict("color" => get_plot_color(agent)),
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
        _save_plot(Plot(configs, main_configuration), file_path * "_qt.html")
    end

    return
end
