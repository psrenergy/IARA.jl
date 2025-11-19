function build_ui_initial_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots")
    agent_plots_path = joinpath(plots_path, "agents")
    if !isdir(plots_path)
        mkdir(plots_path)
    end
    plot_demand(inputs, plots_path)
    if any_elements(inputs, RenewableUnit; filters = [has_no_bidding_group])
        plot_renewable_generation(inputs, plots_path)
        plot_demand(inputs, plots_path; net_demand = true)
    end
    if any_elements(inputs, RenewableUnit; filters = [!has_no_bidding_group])
        if !ispath(agent_plots_path)
            mkdir(agent_plots_path)
        end
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            plot_renewable_generation(inputs, agent_plots_path; asset_owner_index)
        end
    end
    if any_elements(inputs, VirtualReservoir)
        if !ispath(agent_plots_path)
            mkdir(agent_plots_path)
        end
        for virtual_reservoir_index in index_of_elements(inputs, VirtualReservoir)
            for asset_owner_index in virtual_reservoir_asset_owner_indices(inputs, virtual_reservoir_index)
                plot_inflow(inputs, agent_plots_path; asset_owner_index, virtual_reservoir_index)
            end
        end
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
        title = Dict(
            "text" => title,
            "font" => Dict("size" => title_font_size()),
        ),
        xaxis = Dict(
            "title" => Dict(
                "text" => get_name(inputs, "period"),
                "font" => Dict("size" => axis_title_font_size()),
            ),
            "tickmode" => "array",
            "tickvals" => [i for i in eachindex(plot_ticks)],
            "ticktext" => plot_ticks,
            "tickfont" => Dict("size" => axis_tick_font_size()),
        ),
        yaxis = Dict(
            "title" => Dict(
                "text" => "$(get_name(inputs, demand_name)) [$unit]",
                "font" => Dict("size" => axis_title_font_size()),
            ),
            "tickfont" => Dict("size" => axis_tick_font_size()),
        ),
        legend = Dict(
            "yanchor" => "bottom",
            "xanchor" => "left",
            "yref" => "container",
            "orientation" => "h",
            "font" => Dict("size" => legend_font_size()),
        ),
    )

    _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "$(demand_name).html"))

    return nothing
end

function plot_renewable_generation(inputs::AbstractInputs, plots_path::String; asset_owner_index::Int = null_value(Int))
    num_periods = number_of_periods(inputs)
    num_subperiods = number_of_subperiods(inputs)
    ex_ante_generation, ex_post_generation = get_renewable_generation_to_plot(inputs; asset_owner_index)

    if isempty(ex_ante_generation) || isempty(ex_post_generation)
        return nothing
    end

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

    if !is_null(asset_owner_index)
        ao_label = asset_owner_label(inputs, asset_owner_index)
        title = "$ao_label - $title"
    end

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
        title = Dict(
            "text" => title,
            "font" => Dict("size" => title_font_size()),
        ),
        xaxis = Dict(
            "title" => Dict(
                "text" => get_name(inputs, "period"),
                "font" => Dict("size" => axis_title_font_size()),
            ),
            "tickmode" => "array",
            "tickvals" => [i for i in eachindex(plot_ticks)],
            "ticktext" => plot_ticks,
            "tickfont" => Dict("size" => axis_tick_font_size()),
        ),
        yaxis = Dict(
            "title" => Dict(
                "text" => "$(get_name(inputs, "renewable_generation")) [$unit]",
                "font" => Dict("size" => axis_title_font_size()),
            ),
            "tickfont" => Dict("size" => axis_tick_font_size()),
        ),
        legend = Dict(
            "yanchor" => "bottom",
            "xanchor" => "left",
            "yref" => "container",
            "orientation" => "h",
            "font" => Dict("size" => legend_font_size()),
        ),
    )

    if is_null(asset_owner_index)
        _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "renewable_generation.html"))
    else
        _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "renewable_generation_$(ao_label).html"))
    end

    return nothing
end

function plot_inflow(inputs::AbstractInputs, plots_path::String; asset_owner_index::Int, virtual_reservoir_index::Int)
    num_periods = number_of_periods(inputs)
    num_subperiods = number_of_subperiods(inputs)
    ex_ante_inflow_energy, ex_post_inflow_energy =
        get_inflow_energy_to_plot(inputs; asset_owner_index, virtual_reservoir_index)

    if isempty(ex_ante_inflow_energy) || isempty(ex_post_inflow_energy)
        return nothing
    end

    ex_post_min_inflow = dropdims(minimum(ex_post_inflow_energy; dims = 1); dims = 1)
    ex_post_max_inflow = dropdims(maximum(ex_post_inflow_energy; dims = 1); dims = 1)

    # Add artifical agent dimension to get plot ticks
    ticks = [ex_ante_inflow_energy'; ex_post_min_inflow'; ex_post_max_inflow']

    configs = Vector{Config}()
    plot_ticks, hover_ticks =
        _get_plot_ticks(ticks, num_periods, initial_date_time(inputs), time_series_step(inputs))
    title = get_name(inputs, "inflow_energy")
    unit = "MWh"
    color_idx = 0

    ao_label = asset_owner_label(inputs, asset_owner_index)
    vr_label = virtual_reservoir_label(inputs, virtual_reservoir_index)
    title = "$ao_label - $vr_label - $title"

    # Ex-post max inflow
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_post_max_inflow,
            name = get_name(inputs, "maximum_inflow_energy"),
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )
    # Ex-ante inflow
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_ante_inflow_energy,
            name = get_name(inputs, "average_inflow_energy"),
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )
    # Ex-post min inflow
    color_idx += 1
    push!(
        configs,
        Config(;
            x = 1:(num_periods*num_subperiods),
            y = ex_post_min_inflow,
            name = get_name(inputs, "minimum_inflow_energy"),
            line = Dict("color" => _get_plot_color(color_idx)),
            type = "line",
            text = hover_ticks,
            hovertemplate = "%{y} $unit<br>%{text}",
        ),
    )

    main_configuration = Config(;
        title = Dict(
            "text" => title,
            "font" => Dict("size" => title_font_size()),
        ),
        xaxis = Dict(
            "title" => Dict(
                "text" => get_name(inputs, "period"),
                "font" => Dict("size" => axis_title_font_size()),
            ),
            "tickmode" => "array",
            "tickvals" => [i for i in eachindex(plot_ticks)],
            "ticktext" => plot_ticks,
            "tickfont" => Dict("size" => axis_tick_font_size()),
        ),
        yaxis = Dict(
            "title" => Dict(
                "text" => "$(get_name(inputs, "inflow_energy")) [$unit]",
                "font" => Dict("size" => axis_title_font_size()),
            ),
            "tickfont" => Dict("size" => axis_tick_font_size()),
        ),
        legend = Dict(
            "yanchor" => "bottom",
            "xanchor" => "left",
            "yref" => "container",
            "orientation" => "h",
            "font" => Dict("size" => legend_font_size()),
        ),
    )

    _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "inflow_energy_$(vr_label)_$(ao_label).html"))

    return nothing
end
