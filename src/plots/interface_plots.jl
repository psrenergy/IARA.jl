function build_ui_operator_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots", "operator")
    mkdir(plots_path)

    return nothing

end

function build_ui_agents_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots", "agents")
    mkdir(plots_path)

    # Bidding group file labels
    labels_per_asset_owner = Vector{Vector{String}}(undef, number_of_elements(inputs, AssetOwner))
    for asset_owner_index in index_of_elements(inputs, AssetOwner)
        bidding_group_labels = bidding_group_label(inputs)[bidding_group_asset_owner_index(inputs).==asset_owner_index]
        labels_to_read = String[]
        for bg in bidding_group_labels
            for bus in bus_label(inputs)
                push!(labels_to_read, "$bg - $bus")
            end
        end
        labels_per_asset_owner[asset_owner_index] = labels_to_read
    end

    # Revenue
    revenue_file_path = get_revenue_file(inputs)
    if isfile(revenue_file_path)
        filename = get_filename(basename(revenue_file_path))
        for (asset_owner_index, asset_owner_label) in enumerate(asset_owner_label(inputs))
            custom_plot(
                revenue_file_path,
                PlotTimeSeriesStackedMean;
                plot_path = joinpath(plots_path, "$(filename)_$(asset_owner_label)"),
                agents = labels_per_asset_owner[asset_owner_index],
                title = "$asset_owner_label - Bidding Group Revenue",
                add_suffix_to_title = false,
                simplified_ticks = true,
            )
        end
    end

    # Generation
    # TODO: sum over segment dimension
    generation_files = get_generation_files(output_path(inputs), post_processing_path(inputs); from_ex_post = true)
    if isempty(generation_files)
        generation_files = get_generation_files(output_path(inputs), post_processing_path(inputs); from_ex_post = false)
    end
    for generation_file in generation_files
        filename = get_filename(basename(generation_file))
        for (asset_owner_index, asset_owner_label) in enumerate(asset_owner_label(inputs))
            custom_plot(
                generation_file,
                PlotTimeSeriesStackedMean;
                plot_path = joinpath(plots_path, "$(filename)_$(asset_owner_label)"),
                agents = labels_per_asset_owner[asset_owner_index],
                title = "$asset_owner_label - Bidding Group Generation",
                add_suffix_to_title = false,
                simplified_ticks = true,
            )
        end
    end

    return nothing
end

function build_ui_general_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots", "general")
    mkdir(plots_path)

    # Spot price
    custom_plot(
        get_load_marginal_cost_file(inputs),
        PlotTimeSeriesAll;
        plot_path = joinpath(plots_path, "spot_price"),
        title = "Spot Price",
        add_suffix_to_title = false,
        simplified_ticks = true,
    )

    # Generation by technology
    generation_file_path = joinpath(post_processing_path(inputs), "generation.csv")
    if isfile(generation_file_path)
        # Generation
        custom_plot(
            generation_file_path,
            PlotTimeSeriesStackedMean;
            plot_path = joinpath(plots_path, "generation_by_technology"),
            title = "Generation by Technology",
            add_suffix_to_title = false,
            simplified_ticks = true,
            agents = ["hydro", "thermal", "renewable", "battery_unit"], # Does not include deficit
        )
        # Deficit
        custom_plot(
            generation_file_path,
            PlotTimeSeriesMean;
            plot_path = joinpath(plots_path, "deficit"),
            title = "Deficit",
            add_suffix_to_title = false,
            simplified_ticks = true,
            agents = ["deficit"], # Does not include deficit
        )
    end

    # Offer curve
    plot_offer_curve(inputs, plots_path)

    return nothing
end

function build_ui_plots(
    inputs::Inputs,
)
    @info("Building UI plots")

    plots_path = joinpath(output_path(inputs), "plots")
    if !isdir(plots_path)
        mkdir(plots_path)
    end

    build_ui_general_plots(inputs)
    build_ui_operator_plots(inputs)
    build_ui_agents_plots(inputs)

    return nothing
end

function plot_offer_curve(inputs::AbstractInputs, plots_path::String)
    offer_files = get_offer_file_paths(inputs)
    if !isempty(offer_files)
        quantity_offer_file = offer_files[1]
        price_offer_file = offer_files[2]

        quantity_data, quantity_metadata = read_timeseries_file(quantity_offer_file)
        price_data, price_metadata = read_timeseries_file(price_offer_file)

        @assert quantity_metadata.number_of_time_series == price_metadata.number_of_time_series "Mismatch between quantity and price offer file columns"
        @assert quantity_metadata.dimension_size == price_metadata.dimension_size "Mismatch between quantity and price offer file dimensions"
        @assert quantity_metadata.labels == price_metadata.labels "Mismatch between quantity and price offer file labels"

        num_labels = quantity_metadata.number_of_time_series
        num_periods, num_scenarios, num_subperiods, num_bid_segments = quantity_metadata.dimension_size
        num_buses = number_of_elements(inputs, Bus)

        # Remove the period dimension
        if num_periods > 1
            # From input files, with all periods
            quantity_data = quantity_data[:, :, :, :, inputs.args.period]
            price_data = price_data[:, :, :, :, inputs.args.period]
        else
            # Or from heuristic bid output files, with a single period
            quantity_data = dropdims(quantity_data; dims = 5)
            price_data = dropdims(price_data; dims = 5)
        end

        for subperiod in 1:num_subperiods
            reshaped_quantity = [Float64[] for bus in 1:num_buses]
            reshaped_price = [Float64[] for bus in 1:num_buses]

            for segment in 1:num_bid_segments
                for label_index in 1:num_labels
                    bus_index = _get_bus_index(quantity_metadata.labels[label_index], bus_label(inputs))
                    # mean across scenarios
                    quantity = mean(quantity_data[label_index, segment, subperiod, :])
                    price = mean(price_data[label_index, segment, subperiod, :])
                    # push point
                    push!(reshaped_quantity[bus_index], quantity)
                    push!(reshaped_price[bus_index], price)
                end
            end

            for bus in 1:num_buses
                sort_order = sortperm(reshaped_price[bus])
                reshaped_quantity[bus] = reshaped_quantity[bus][sort_order]
                reshaped_quantity[bus] = cumsum(reshaped_quantity[bus])
                reshaped_price[bus] = reshaped_price[bus][sort_order]
            end

            quantity_data_to_plot = [Float64[0.0] for bus in 1:num_buses]
            price_data_to_plot = [Float64[0.0] for bus in 1:num_buses]

            for bus in 1:num_buses
                for (quantity, price) in zip(reshaped_quantity[bus], reshaped_price[bus])
                    # old point
                    push!(quantity_data_to_plot[bus], quantity_data_to_plot[bus][end])
                    push!(price_data_to_plot[bus], price)
                    # new point
                    push!(quantity_data_to_plot[bus], quantity)
                    push!(price_data_to_plot[bus], price)
                end
            end

            configs = Vector{Config}()

            title = "Available Offers - Subperiod $subperiod"
            for bus in 1:num_buses
                push!(
                    configs,
                    Config(;
                        x = quantity_data_to_plot[bus],
                        y = price_data_to_plot[bus],
                        name = bus_label(inputs, bus),
                        line = Dict("color" => _get_plot_color(bus)),
                        type = "line",
                    ),
                )
            end

            main_configuration = Config(;
                title = title,
                xaxis = Dict("title" => "Quantity [MWh]"),
                yaxis = Dict("title" => "Price [\$/MWh]"),
            )

            _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "offer_curve_subperiod_$subperiod.html"))
        end
    end

    return nothing
end

function plot_demand(inputs::AbstractInputs, plots_path::String)
    demand_file = if read_ex_ante_demand_file(inputs)
        joinpath(path_case(inputs), demand_unit_demand_ex_ante_file(inputs))
    elseif read_ex_post_demand_file(inputs)
        joinpath(path_case(inputs), demand_unit_demand_ex_post_file(inputs))
    else
        ""
    end
    demand_file *= InterfaceCalls.timeseries_file_extension(demand_file)
    if isfile(demand_file)
        data, metadata = read_timeseries_file(demand_file)
        # Average across subscenarios for ex-post file
        data_reshaped = if !read_ex_ante_demand_file(inputs)
            dropdims(mean(data; dims = 3); dims = 3)
        else
            data
        end
        data_reshaped = merge_period_subperiod(data_reshaped)
        # Sum all units
        total_demand = zeros(1, size(data_reshaped)[2:end]...)
        for demand_index in 1:number_of_elements(inputs, DemandUnit)
            total_demand[1, :, :] .+= data_reshaped[demand_index, :, :] * demand_unit_max_demand(inputs, demand_index)
        end
        demand_to_plot, names = agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, total_demand, ["Total demand"])

        time_series_length = size(demand_to_plot, 2)

        configs = Vector{Config}()
        plot_ticks, hover_ticks =
            _get_plot_ticks(demand_to_plot, size(data)[end], initial_date_time(inputs), time_series_step(inputs))
        unit = "MW"
        p10_idx = 1
        p50_idx = 2
        p90_idx = 3
        push!(configs,
            Config(;
                x = vcat(1:time_series_length, time_series_length:-1:1),
                y = vcat(demand_to_plot[p10_idx, :], reverse(demand_to_plot[p90_idx, :])),
                name = names[1] * " (P10 - P90)",
                fill = "toself",
                line = Dict("color" => "transparent"),
                fillcolor = _get_plot_color(1; transparent = true),
                type = "line",
                text = hover_ticks,
                hovertemplate = "%{y} $unit",
                hovermode = "closest",
            ))
        push!(configs,
            Config(;
                x = 1:time_series_length,
                y = demand_to_plot[p50_idx, :],
                name = names[1] * " (P50)",
                line = Dict("color" => _get_plot_color(1)),
                type = "line",
                text = hover_ticks,
                hovertemplate = "%{y} $unit<br>%{text}",
            ))

        main_configuration = Config(;
            title = "Total demand",
            xaxis = Dict(
                "title" => "Period",
                "tickmode" => "array",
                "tickvals" => [i for i in eachindex(plot_ticks)],
                "ticktext" => plot_ticks,
            ),
            yaxis = Dict("title" => unit),
        )
        _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "total_demand.html"))
    end
    return nothing
end
