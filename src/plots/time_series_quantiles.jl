#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

abstract type PlotTimeSeriesQuantiles <: PlotType end

function agent_quantile_in_scenarios(
    ::Type{PlotTimeSeriesQuantiles},
    data::Array{Float64, 3},
    agent_names::Vector{String},
)
    num_stages = size(data, 3)
    num_agents = size(data, 1)

    reshaped_data = Array{Float64, 2}(undef, 3 * num_agents, num_stages)
    for agent in 1:num_agents
        p10_idx = agent
        p50_idx = num_agents + agent
        p90_idx = 2 * num_agents + agent
        all_agent_indexes = [p10_idx, p50_idx, p90_idx]
        for stage in 1:num_stages
            reshaped_data[all_agent_indexes, stage] =
                quantile(data[agent, :, stage], [0.1, 0.5, 0.9])
        end
    end
    return reshaped_data, agent_names
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesQuantiles},
    data::Array{Float32, 3},
    agent_names::Vector{String},
    dimensions::Vector{String},
)
    time_series, agent_names = agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, data, agent_names)
    return time_series, agent_names
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesQuantiles},
    data::Array{Float32, 4},
    agent_names::Vector{String},
    dimensions::Vector{String},
)
    if !("block" in dimensions) && ("bid_segment" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names)
        time_series, agent_names = agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names)
        return time_series, agent_names
    elseif ("block" in dimensions) && !("bid_segment" in dimensions)
        time_series = merge_stage_block(data)
        time_series, agent_names = agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names)
        return time_series, agent_names
    else
        error(
            "A time series output with 4 dimensions should have either 'bid_segment' or 'block' as a dimension.",
        )
    end
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesQuantiles},
    data::Array{Float32, 5},
    agent_names::Vector{String},
    dimensions::Vector{String},
)
    if !("subscenario" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names)
        time_series = merge_stage_block(time_series)
        time_series, agent_names = agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names)
        return time_series, agent_names
    elseif !("bid_segment" in dimensions)
        time_series = merge_stage_block(data)
        time_series, modified_scenario_names =
            merge_scenario_subscenario(time_series, agent_names)
        time_series, modified_agent_names =
            agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names)
        return time_series, modified_agent_names
    elseif !("block" in dimensions)
        time_series, modified_names = merge_segment_agent(data, agent_names)
        time_series, modified_scenario_names =
            merge_scenario_subscenario(time_series, modified_names)
        time_series, modified_agent_names =
            agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, modified_names)
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
    dimensions::Vector{String},
)
    time_series, agent_names = merge_segment_agent(data, agent_names)
    time_series = merge_stage_block(time_series)
    time_series, modified_scenario_names = merge_scenario_subscenario(time_series, agent_names)
    time_series, modified_agent_names = agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, time_series, agent_names)
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
    stage_type::Configurations_StageType.T,
) where {N}
    traces, trace_names = reshape_time_series!(PlotTimeSeriesQuantiles, data, agent_names, dimensions)
    number_of_stages = size(traces, 2)
    number_of_agents = length(trace_names)

    initial_number_of_stages = size(data, N)
    plot_ticks, hover_ticks = get_plot_ticks(traces, initial_number_of_stages, initial_date, stage_type)
    plot_type = ifelse(number_of_stages == 1, "bar", "line")
    plot_ref = plot()

    title = title * " - Scenario quantiles"
    for agent in 1:number_of_agents
        p10_idx = agent
        p50_idx = number_of_agents + agent
        p90_idx = 2 * number_of_agents + agent
        plot_ref(;
            x = vcat(1:number_of_stages, number_of_stages:-1:1),
            y = vcat(traces[p10_idx, :], reverse(traces[p90_idx, :])),
            name = trace_names[agent] * " (P10 - P90)",
            fill = "toself",
            line = Dict("color" => "transparent"),
            fillcolor = get_plot_color(agent; transparent = true),
            type = plot_type,
            text = hover_ticks,
            hovertemplate = "%{y} $unit",
            hovermode = "closest",
        )
        plot_ref(;
            x = 1:number_of_stages,
            y = traces[p50_idx, :],
            name = trace_names[agent] * " (P50)",
            line = Dict("color" => get_plot_color(agent)),
            type = plot_type,
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        )
    end

    plot_ref.layout.title.text = title
    plot_ref.layout.yaxis.title = unit
    plot_ref.layout.xaxis.automargin = true
    plot_ref.layout.xaxis = Dict(
        "title" => "Stage",
        "tickmode" => "array",
        "tickvals" => [i for i in eachindex(plot_ticks)],
        "ticktext" => plot_ticks,
    )

    _save_plot(plot_ref, file_path * "_qt.html")

    return
end
