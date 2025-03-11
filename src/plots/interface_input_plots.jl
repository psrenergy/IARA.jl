function build_ui_initial_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots")
    if !isdir(plots_path)
        mkdir(plots_path)
    end
    plot_demand(inputs, plots_path)

    return nothing
end

function plot_demand(inputs::AbstractInputs, plots_path::String)
    num_periods = number_of_periods(inputs)
    num_subperiods = number_of_subperiods(inputs)
    ex_ante_demand, ex_post_min_demand, ex_post_max_demand = get_demands_to_plot(inputs)

    # Add artifical agent dimension to get plot ticks
    ticks_demand = [ex_ante_demand'; ex_post_min_demand'; ex_post_max_demand']

    configs = Vector{Config}()
    plot_ticks, hover_ticks =
        _get_plot_ticks(ticks_demand, num_periods, initial_date_time(inputs), time_series_step(inputs))
    title = "Demand"
    unit = "MW"
    color_idx = 0

    # Ex-post max demand
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_post_max_demand,
            name = "Ex-post maximum demand",
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )
    # Ex-ante demand
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_ante_demand,
            name = "Ex-ante demand",
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )
    # Ex-post min demand
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_post_min_demand,
            name = "Ex-post minimum demand",
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )

    main_configuration = Config(;
        title = title,
        xaxis = Dict(
            "title" => "Period",
            "tickmode" => "array",
            "tickvals" => [i for i in eachindex(plot_ticks)],
            "ticktext" => plot_ticks,
        ),
        yaxis = Dict("title" => "Demand [$unit]"),
    )

    _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "total_demand.html"))

    return nothing
end
