#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function _filter_time_series(
    data::Array{<:AbstractFloat, N},
    metadata::Quiver.Metadata,
    agents::Vector{String};
    kwargs...,
) where {N}
    queried_dimensions = keys(kwargs)

    queried_indices = []

    labels_indices = Vector{Int}()
    for agent_names in agents
        if agent_names in metadata.labels
            push!(labels_indices, findfirst(x -> x == agent_names, metadata.labels))
        else
            error("Agent $agent_names not found in this file's labels")
        end
    end
    push!(queried_indices, labels_indices)

    for i in length(metadata.dimensions):-1:1
        if metadata.dimensions[i] in queried_dimensions
            if typeof(kwargs[metadata.dimensions[i]]) == UnitRange{Int}
                push!(queried_indices, [i for i in kwargs[metadata.dimensions[i]]])
            else
                push!(queried_indices, [kwargs[metadata.dimensions[i]]])
            end
        else
            push!(queried_indices, [i for i in 1:metadata.dimension_size[i]])
        end
    end

    filtered_data = data[queried_indices...]
    return filtered_data
end

function _get_adjusted_date_time(
    initial_date::DateTime,
    time_series_step::Configurations_TimeSeriesStep.T,
    period::Union{Int, UnitRange},
)
    if time_series_step == Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
        if period isa Int
            return initial_date + Dates.Month(period - 1)
        else
            return initial_date + Dates.Month(first(period) - 1)
        end
    end
end

function _compare_axis(axis_a::Config, axis_b::Config)
    if haskey(axis_a, :ticktext) && haskey(axis_b, :ticktext)
        if axis_a["ticktext"] != axis_b["ticktext"]
            return false
        end
    end
    if haskey(axis_a, :tickvals) && haskey(axis_b, :tickvals)
        if axis_a["tickvals"] != axis_b["tickvals"]
            return false
        end
    end
    if haskey(axis_a, :tickmode) && haskey(axis_b, :tickmode)
        if axis_a["tickmode"] != axis_b["tickmode"]
            return false
        end
    end
    if haskey(axis_a, :title) && haskey(axis_b, :title)
        if axis_a["title"] != axis_b["title"]
            return false
        end
    end
    return true
end

"""
    custom_plot(
        filepath::String, 
        plot_type::Type{<:PlotType}; 
        plot_path::String = "",
        agents::Vector{String} = Vector{String}(), 
        title::String = "Plot", 
        kwargs...
    )

Create a customized plot from a time series file.

- It requires a plot type [`PlotType`] and a file path to a time series file. 
- The `plot_path` argument is used to set the path where the plot will be saved. If it is not provided, the plot will not be saved.
- The `agents` argument is used to filter the agents to be plotted. If it is not provided, all agents will be plotted.
- The `title` argument is used to set the title of the plot, which is "Plot" by default.
- The `kwargs` arguments are used to filter the time series by its dimensions.

Example:

```julia
path = "path/to/file.csv"
IARA.custom_plot(path, PlotTimeSeriesQuantiles; subperiod = 1:10, agents=["hydro"])
```
"""
function custom_plot(
    filepath::String,
    plot_type::Type{<:PlotType};
    plot_path::String = "",
    agents::Vector{String} = Vector{String}(),
    title::String = "Plot",
    add_suffix_to_title::Bool = true,
    simplified_ticks::Bool = false,
    kwargs...,
)
    # kwargs contains the dimensions
    queried_dimensions = keys(kwargs)

    data, metadata = read_timeseries_file(filepath)

    for dimension in queried_dimensions
        if !(dimension in metadata.dimensions)
            error("Queried dimension $dimension is not in this file's dimensions")
        end
    end

    if isempty(agents)
        agents = String.(metadata.labels)
    end

    data_to_plot = _filter_time_series(data, metadata, agents; kwargs...)

    time_series_step = if metadata.frequency == "monthly" || metadata.frequency == "month"
        Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
    end

    queried_period = get(kwargs, :period, nothing)

    initial_date = if !isnothing(queried_period)
        _get_adjusted_date_time(DateTime(metadata.initial_date), time_series_step, queried_period)
    else
        DateTime(metadata.initial_date)
    end

    return plot_data(
        plot_type,
        data_to_plot,
        agents,
        String.(metadata.dimensions);
        title = title,
        unit = metadata.unit,
        file_path = plot_path,
        initial_date = initial_date,
        time_series_step = time_series_step,
        add_suffix_to_title = add_suffix_to_title,
        simplified_ticks = simplified_ticks,
        kwargs...,
    )
end

"""
    IARA.custom_plot(plot_a::Plot, plot_b::Plot; title::String = "Plot")

Create a customized plot from two plots.

- It requires a vector of plots that you have already created with `IARA.custom_plot`.
- The x-axis of the two plots must be the same.

Example:

```julia
path_1 = "path/to/file.csv"
path_2 = "path/to/another_file.csv"


plot_1 = IARA.custom_plot(path_1, IARA.PlotTimeSeriesQuantiles; subperiod = 1:10, agents=["hydro"])
plot_2 = IARA.custom_plot(path_2, IARA.PlotTimeSeriesQuantiles; subperiod = 1:10, agents=["thermal"])

IARA.custom_plot(plot_1, plot_2; title = "Custom Plot")
```
"""
function custom_plot(
    plot_a::Plot,
    plot_b::Plot;
    title::Union{String, Nothing} = nothing,
    identifier_a::String = "_(1)",
    identifier_b::String = "_(2)",
)
    different_y_axis = false
    configs = Vector{Config}()

    if isnothing(title)
        title = plot_a.layout.title * " || " * plot_b.layout.title
    end

    main_config = Config(;
        title = title,
        margin = Dict("l" => 60, "r" => 60, "t" => 60, "b" => 60),
    )

    if _compare_axis(plot_a.layout.xaxis, plot_b.layout.xaxis)
        main_config.xaxis = plot_a.layout.xaxis
    else
        error("The x-axis of the two plots must be the same")
    end
    if _compare_axis(plot_a.layout.yaxis, plot_b.layout.yaxis)
        main_config.yaxis = plot_a.layout.yaxis
    else
        main_config[:yaxis] = plot_a.layout.yaxis

        main_config[:yaxis2] = plot_b.layout.yaxis
        main_config[:yaxis2][:overlaying] = "y"
        main_config[:yaxis2][:side] = "right"
        main_config[:yaxis2][:tickfont] = Dict("color" => "#1f77b4")
        main_config[:yaxis2][:titlefont] = Dict("color" => "#1f77b4")

        different_y_axis = true
    end

    for config in plot_a.data
        new_config = Config()
        for key in keys(config)
            if key == :name
                if typeof(config.name) == String
                    new_config[:name] = config.name * identifier_a
                end
            elseif key == :legendgroup
                new_config[:legendgroup] = config.legendgroup * identifier_a
            else
                new_config[key] = config[key]
            end
        end
        push!(configs, new_config)
    end
    for config in plot_b.data
        new_config = Config()
        for key in keys(config)
            if key == :name
                if typeof(config.name) == String
                    new_config[:name] = config.name * identifier_b
                end
            elseif key == :legendgroup
                new_config[:legendgroup] = config.legendgroup * identifier_b
            else
                new_config[key] = config[key]
            end
        end
        if different_y_axis
            new_config[:yaxis] = "y2"
        end
        push!(configs, new_config)
    end

    main_config[:legend] = Dict("x" => 1.06, "y" => 1)

    return Plot(configs, main_config)
end
