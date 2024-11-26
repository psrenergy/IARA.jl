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
    PlotTimeSeriesAll

Type for a time series plot with all scenarios.
"""
abstract type PlotTimeSeriesAll <: PlotType end

function merge_scenario_agent(
    ::Type{PlotTimeSeriesAll},
    data::Array{Float64, 3},
    agent_names::Vector{String},
    scenario_names::Union{Vector{String}, Nothing} = nothing;
    kwargs...,
)
    num_periods = size(data, 3)
    num_scenarios = size(data, 2)
    num_agents = size(data, 1)

    queried_scenarios = get(kwargs, :scenario, nothing)

    reshaped_data = Array{Float64, 2}(undef, num_scenarios * num_agents, num_periods)
    modified_names = Vector{String}(undef, num_scenarios * num_agents)
    i = 1
    for agent in 1:num_agents
        for scenario in 1:num_scenarios
            reshaped_data[i, :] = data[agent, scenario, :]
            if isnothing(scenario_names)
                scenario_true_index = isnothing(queried_scenarios) ? scenario : queried_scenarios[scenario]
                modified_names[i] = agent_names[agent] * " ( Scenario $(scenario_true_index) )"
            else
                modified_names[i] = agent_names[agent] * " " * scenario_names[scenario]
            end
            i += 1
        end
    end
    return reshaped_data, modified_names
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesAll},
    data::Array{Float32, 3},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    time_series, agent_names = merge_scenario_agent(PlotTimeSeriesAll, data, agent_names; kwargs...)
    return time_series, agent_names
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesAll},
    data::Array{Float32, 4},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    if !("subperiod" in dimensions) && ("bid_segment" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
        time_series, agent_names = merge_scenario_agent(PlotTimeSeriesAll, time_series, agent_names; kwargs...)
        return time_series, agent_names
    elseif ("subperiod" in dimensions) && !("bid_segment" in dimensions)
        time_series = merge_period_subperiod(data)
        time_series, agent_names = merge_scenario_agent(PlotTimeSeriesAll, time_series, agent_names; kwargs...)
        return time_series, agent_names
    else
        error(
            "A time series output with 4 dimensions should have either 'bid_segment' or 'subperiod' as a dimension.",
        )
    end
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesAll},
    data::Array{Float32, 5},
    agent_names::Vector{String},
    dimensions::Vector{String};
    kwargs...,
)
    if !("subscenario" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
        time_series = merge_period_subperiod(time_series)
        time_series, agent_names = merge_scenario_agent(PlotTimeSeriesAll, time_series, agent_names; kwargs...)
        return time_series, agent_names
    elseif !("bid_segment" in dimensions)
        time_series = merge_period_subperiod(data)
        time_series, modified_scenario_names = merge_scenario_subscenario(time_series, agent_names; kwargs...)
        time_series, modified_agent_names =
            merge_scenario_agent(PlotTimeSeriesAll, time_series, agent_names, modified_scenario_names; kwargs...)
        return time_series, modified_agent_names
    elseif !("subperiod" in dimensions)
        time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
        time_series, modified_scenario_names = merge_scenario_subscenario(time_series, agent_names; kwargs...)
        time_series, modified_agent_names =
            merge_scenario_agent(PlotTimeSeriesAll, time_series, agent_names, modified_scenario_names; kwargs...)
        return time_series, modified_agent_names
    else
        error(
            "A time series output with 5 dimensions should have either 'bid_segment' or 'subscenario' as a dimension.",
        )
    end
end

function reshape_time_series!(
    ::Type{PlotTimeSeriesAll},
    data::Array{Float32, 6},
    agent_names::Vector{String},
    dimensions::Vector{String},
    kwargs...,
)
    time_series, agent_names = merge_segment_agent(data, agent_names; kwargs...)
    time_series = merge_period_subperiod(time_series)
    time_series, modified_scenario_names = merge_scenario_subscenario(time_series, agent_names; kwargs...)
    time_series, modified_agent_names =
        merge_scenario_agent(PlotTimeSeriesAll, time_series, agent_names, modified_scenario_names; kwargs...)
    return time_series, modified_agent_names
end

"""
    plot_data(::Type{PlotTimeSeriesAll}, data::Array{Float32, N}, agent_names::Vector{String}, dimensions::Vector{String}; title::String = "", unit::String = "", file_path::String, initial_date::DateTime, period_type::Configurations_PeriodType.T, kwargs...)

Create a time series plot with all scenarios.
"""
function plot_data(
    ::Type{PlotTimeSeriesAll},
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
    traces, trace_names = reshape_time_series!(PlotTimeSeriesAll, data, agent_names, dimensions; kwargs...)
    number_of_periods = size(traces, 2)
    number_of_traces = size(traces, 1)

    initial_number_of_periods = size(data, N)
    plot_ticks, hover_ticks = _get_plot_ticks(traces, initial_number_of_periods, initial_date, period_type; kwargs...)

    plot_type = ifelse(number_of_periods == 1, "bar", "line")

    configs = Vector{Config}()

    title = title * " - Individual scenarios"
    for trace in 1:number_of_traces
        push!(
            configs,
            Config(;
                x = 1:number_of_periods,
                y = traces[trace, :],
                name = trace_names[trace],
                line = Dict("color" => _get_plot_color(trace)),
                type = plot_type,
                text = hover_ticks,
                hovertemplate = "%{y} $unit<br>%{text}",
            ),
        )
    end

    main_configuration = Config(;
        title = title,
        xaxis = Dict(
            "title" => "Period",
            "tickmode" => "array",
            "tickvals" => [i for i in eachindex(plot_ticks)],
            "ticktext" => plot_ticks,
        ),
        yaxis = Dict("title" => unit))

    if file_path == ""
        return Plot(configs, main_configuration)
    else
        _save_plot(Plot(configs, main_configuration), file_path * "_all.html")
    end

    return
end
