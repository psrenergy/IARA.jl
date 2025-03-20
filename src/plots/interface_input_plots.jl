function build_ui_initial_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots")
    if !isdir(plots_path)
        mkdir(plots_path)
    end
    plot_demand(inputs, plots_path)
    if any_elements(inputs, RenewableUnit; filters = [has_no_bidding_group])
        plot_renewable_generation(inputs, plots_path)
        plot_demand(inputs, plots_path; net_demand = true)
    end

    return nothing
end

function plot_demand(inputs::AbstractInputs, plots_path::String; net_demand = false)
    num_periods = number_of_periods(inputs)
    num_subperiods = number_of_subperiods(inputs)
    ex_ante_demand, ex_post_demand = get_demands_to_plot(inputs)

    if net_demand
        ex_ante_generation, ex_post_generation = get_renewable_generation_to_plot(inputs)
        ex_ante_demand = ex_ante_demand .- ex_ante_generation
        ex_post_demand = ex_post_demand .- ex_post_generation
    end

    ex_post_min_demand = dropdims(minimum(ex_post_demand; dims = 1); dims = 1)
    ex_post_max_demand = dropdims(maximum(ex_post_demand; dims = 1); dims = 1)

    # Add artifical agent dimension to get plot ticks
    ticks_demand = [ex_ante_demand'; ex_post_min_demand'; ex_post_max_demand']

    demand_name = if net_demand
        "net_demand"
    else
        "total_demand"
    end

    configs = Vector{Config}()
    plot_ticks, hover_ticks =
        _get_plot_ticks(
            ticks_demand,
            num_periods,
            initial_date_time(inputs),
            time_series_step(inputs);
            subperiod_string = get_name(inputs, "subperiod"),
        )
    title = get_name(inputs, demand_name)
    unit = "MW"
    color_idx = 0

    # Ex-post max demand
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_post_max_demand,
            name = get_name(inputs, "maximum_$demand_name"),
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
            name = get_name(inputs, "average_$demand_name"),
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
            name = get_name(inputs, "minimum_$demand_name"),
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )

    main_configuration = Config(;
        title = title,
        xaxis = Dict(
            "title" => get_name(inputs, "period"),
            "tickmode" => "array",
            "tickvals" => [i for i in eachindex(plot_ticks)],
            "ticktext" => plot_ticks,
        ),
        yaxis = Dict("title" => "$(get_name(inputs, demand_name)) [$unit]"),
    )

    _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "$(demand_name).html"))

    return nothing
end

function plot_renewable_generation(inputs::AbstractInputs, plots_path::String)
    num_periods = number_of_periods(inputs)
    num_subperiods = number_of_subperiods(inputs)
    ex_ante_generation, ex_post_generation = get_renewable_generation_to_plot(inputs)

    ex_post_min_generation = dropdims(minimum(ex_post_generation; dims = 1); dims = 1)
    ex_post_max_generation = dropdims(maximum(ex_post_generation; dims = 1); dims = 1)

    # Add artifical agent dimension to get plot ticks
    ticks = [ex_ante_generation'; ex_post_min_generation'; ex_post_max_generation']

    configs = Vector{Config}()
    plot_ticks, hover_ticks =
        _get_plot_ticks(ticks, num_periods, initial_date_time(inputs), time_series_step(inputs))
    title = get_name(inputs, "renewable_generation")
    unit = "MW"
    color_idx = 0

    # Ex-post max generation
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_post_max_generation,
            name = get_name(inputs, "maximum_renewable_generation"),
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )
    # Ex-ante generation
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_ante_generation,
            name = get_name(inputs, "average_renewable_generation"),
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )
    # Ex-post min generation
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_post_min_generation,
            name = get_name(inputs, "minimum_renewable_generation"),
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )

    main_configuration = Config(;
        title = title,
        xaxis = Dict(
            "title" => get_name(inputs, "period"),
            "tickmode" => "array",
            "tickvals" => [i for i in eachindex(plot_ticks)],
            "ticktext" => plot_ticks,
        ),
        yaxis = Dict("title" => "$(get_name(inputs, "renewable_generation")) [$unit]"),
    )

    _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "renewable_generation.html"))

    return nothing
end
