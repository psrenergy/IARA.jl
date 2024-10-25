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
    data::Array{<:Real, N},
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
    period_type::Configurations_PeriodType.T,
    period::Union{Int, UnitRange},
)
    if period_type == Configurations_PeriodType.MONTHLY
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
    custom_plot(filepath::String, plot_type::Type{<:PlotType}; agents::Vector{String} = Vector{String}(), title::String = "Plot", kwargs...)

Create a customized plot from a time series file.

- It requires a plot type [`PlotType`] and a file path to a time series file. 
- The `agents` argument is used to filter the agents to be plotted. If it is not provided, all agents will be plotted.
- The `title` argument is used to set the title of the plot, which is "Plot" by default.
- The `kwargs` arguments are used to filter the time series by its dimensions.

Example:

```julia
path = "path/to/file.csv"
IARA.custom_plot(path, PlotTimeSeriesMean; subperiod = 1:10, agents=["hydro"])
```
"""
function custom_plot(
    filepath::String,
    plot_type::Type{<:PlotType};
    agents::Vector{String} = Vector{String}(),
    title::String = "Plot",
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

    period_type = if metadata.frequency == "monthly" || metadata.frequency == "month"
        Configurations_PeriodType.MONTHLY
    end

    queried_period = get(kwargs, :period, nothing)

    initial_date = if !isnothing(queried_period)
        _get_adjusted_date_time(DateTime(metadata.initial_date), period_type, queried_period)
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
        file_path = "",
        initial_date = initial_date,
        period_type = period_type,
        kwargs...,
    )
end

"""
    IARA.custom_plot(
        filepath_x::String, 
        filepath_y::String, 
        plot_type::Type{<:IARA.RelationPlotType}; 
        agent_x::String, 
        agent_y::String, 
        title::String = "Plot", 
        x_label::String, 
        y_label::String, 
        flip_x::Bool = false, 
        flip_y::Bool = false, 
        trace_mode::String = "markers", 
        kwargs...
    )

Create a customized plot relating the values for two agents in two different time series files.

- It requires a plot type [`IARA.RelationPlotType`] and a file path to a time series file. 
- The `agent_x` and `agent_y` arguments are used to filter the agents to be plotted, in the x and y axis.
- The `title` argument is used to set the title of the plot, which is "Plot" by default.
- The `x_label` and `y_label` arguments are used to set the labels of the x and y axis.
- The `flip_x` and `flip_y` arguments are used to reverse the x and y axis, respectively.
- The `trace_mode` argument is used to set the trace mode of the plot, which is "markers" by default. 
- The `kwargs` arguments are used to filter the time series by its dimensions.

Example:

```julia
path_x = "path/to/file.csv"
path_y = "path/to/another_file.csv"
IARA.custom_plot(path_x, path_y, IARA.PlotRelationAll; agent_x = "hydro_1", agent_y = "hydro_1", x_label = "volume", y_label = "turbining", flip_x = true, trace_mode= "line")
```
"""
function custom_plot(
    filepath_x::String,
    filepath_y::String,
    plot_type::Type{<:RelationPlotType};
    agent_x::String,
    agent_y::String,
    title::String = "Plot",
    x_label::String,
    y_label::String,
    flip_x::Bool = false,
    flip_y::Bool = false,
    trace_mode::String = "markers",
    kwargs...,
)
    # kwargs contains the dimensions
    queried_dimensions = keys(kwargs)

    data_1, metadata_1 = read_timeseries_file(filepath_x)
    data_2, metadata_2 = read_timeseries_file(filepath_y)

    @assert metadata_1.dimensions == metadata_2.dimensions "The dimensions of the two files must be the same"
    @assert metadata_1.initial_date == metadata_2.initial_date "The initial date of the two files must be the same"
    @assert metadata_1.frequency == metadata_2.frequency "The frequency of the two files must be the same"

    for dimension in queried_dimensions
        if !(dimension in metadata_1.dimensions) || !(dimension in metadata_2.dimensions)
            error("Queried dimension $dimension is not in this files' dimensions")
        end
    end

    if !(agent_x in metadata_1.labels)
        error("Agent $agent_x not found in the first file's labels")
    end
    if !(agent_y in metadata_2.labels)
        error("Agent $agent_y not found in the second file's labels")
    end

    filtered_data_1 = _filter_time_series(data_1, metadata_1, [agent_x]; kwargs...)
    filtered_data_2 = _filter_time_series(data_2, metadata_2, [agent_y]; kwargs...)

    period_type = if metadata_1.frequency == "month" || metadata_1.frequency == "monthly"
        Configurations_PeriodType.MONTHLY
    end

    queried_period = get(kwargs, :period, nothing)

    initial_date = if !isnothing(queried_period)
        _get_adjusted_date_time(DateTime(metadata_1.initial_date), period_type, queried_period)
    else
        DateTime(metadata_1.initial_date)
    end

    return plot_data(
        plot_type,
        filtered_data_1,
        filtered_data_2,
        agent_x,
        agent_y,
        String.(metadata_1.dimensions);
        title = title,
        unit_x = metadata_1.unit,
        unit_y = metadata_2.unit,
        file_path = "",
        initial_date = initial_date,
        period_type = period_type,
        x_label = x_label,
        y_label = y_label,
        flip_x = flip_x,
        flip_y = flip_y,
        trace_mode = trace_mode,
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


plot_1 = IARA.custom_plot(path_1, IARA.PlotTimeSeriesMean; subperiod = 1:10, agents=["hydro"])
plot_2 = IARA.custom_plot(path_2, IARA.PlotTimeSeriesMean; subperiod = 1:10, agents=["thermal"])

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
