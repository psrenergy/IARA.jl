function build_ui_operator_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots", "operator")
    mkdir(plots_path)

    # Profit
    profit_file_path = get_profit_file(inputs)
    plot_path = joinpath(plots_path, "total_profit")
    plot_asset_owner_sum_output(inputs, profit_file_path, plot_path, "Total Profit")

    # Revenue
    revenue_file_path = get_revenue_file(inputs)
    plot_path = joinpath(plots_path, "total_revenue")
    plot_asset_owner_sum_output(inputs, revenue_file_path, plot_path, "Total Revenue")

    # Generation
    generation_files = get_generation_files(output_path(inputs), post_processing_path(inputs); from_ex_post = true)
    if isempty(generation_files)
        generation_files =
            get_generation_files(output_path(inputs), post_processing_path(inputs); from_ex_post = false)
    end
    generation_file = generation_files[1]
    plot_path = joinpath(plots_path, "total_generation")
    plot_asset_owner_sum_output(inputs, generation_file, plot_path, "Total Generation")

    return nothing
end

function build_ui_agents_plots(
    inputs::Inputs;
)
    plots_path = joinpath(output_path(inputs), "plots", "agents")
    mkdir(plots_path)

    # Profit
    profit_file_path = get_profit_file(inputs)
    if isfile(profit_file_path)
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - Profit"
            plot_path = joinpath(plots_path, "profit_$ao_label.html")
            plot_asset_owner_output(inputs, profit_file_path, plot_path, asset_owner_index, title)
        end
    end

    # Revenue
    revenue_file_path = get_revenue_file(inputs)
    if isfile(revenue_file_path)
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - Revenue"
            plot_path = joinpath(plots_path, "revenue_$ao_label.html")
            plot_asset_owner_output(inputs, revenue_file_path, plot_path, asset_owner_index, title)
        end
    end

    # Generation
    generation_files = get_generation_files(output_path(inputs), post_processing_path(inputs); from_ex_post = true)
    if isempty(generation_files)
        generation_files =
            get_generation_files(output_path(inputs), post_processing_path(inputs); from_ex_post = false)
    end
    generation_file = generation_files[1]
    if isfile(generation_file)
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - Generation"
            plot_path = joinpath(plots_path, "generation_$ao_label.html")
            plot_asset_owner_output(inputs, generation_file, plot_path, asset_owner_index, title)
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
    plot_ui_timeseries(;
        file_path = get_load_marginal_cost_file(inputs),
        plot_path = joinpath(plots_path, "spot_price"),
        title = "Spot Price",
    )

    # Generation by technology
    generation_file_path = joinpath(post_processing_path(inputs), "generation.csv")
    if isfile(generation_file_path)
        # Generation
        plot_ui_timeseries(;
            file_path = generation_file_path,
            plot_path = joinpath(plots_path, "generation_by_technology"),
            title = "Generation by Technology",
            agent_labels = ["hydro", "thermal", "renewable", "battery_unit"], # Does not include deficit
            stack = true,
        )
        # Deficit
        plot_ui_timeseries(;
            file_path = generation_file_path,
            plot_path = joinpath(plots_path, "deficit"),
            title = "Deficit",
            agent_labels = ["deficit"],
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
        plot_no_markup_price = false
        quantity_offer_file = offer_files[1]
        price_offer_file = offer_files[2]
        if length(offer_files) == 3
            no_markup_price_offer_file = offer_files[3]
            plot_no_markup_price = true
        end

        quantity_data, quantity_metadata = read_timeseries_file(quantity_offer_file)
        price_data, price_metadata = read_timeseries_file(price_offer_file)
        if plot_no_markup_price
            no_markup_price_data, no_markup_price_metadata = read_timeseries_file(no_markup_price_offer_file)
        end

        @assert quantity_metadata.number_of_time_series == price_metadata.number_of_time_series "Mismatch between quantity and price offer file columns"
        @assert quantity_metadata.dimension_size == price_metadata.dimension_size "Mismatch between quantity and price offer file dimensions"
        @assert quantity_metadata.labels == price_metadata.labels "Mismatch between quantity and price offer file labels"
        if plot_no_markup_price
            @assert no_markup_price_metadata.number_of_time_series == price_metadata.number_of_time_series "Mismatch between reference price and price offer file columns"
            # The number of periods in the reference price file is always 1
            @assert no_markup_price_metadata.dimension_size[2:end] == price_metadata.dimension_size[2:end] "Mismatch between reference price and price offer file dimensions"
            @assert sort(no_markup_price_metadata.labels) == sort(price_metadata.labels) "Mismatch between reference price and price offer file labels"
        end

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
        if plot_no_markup_price
            no_markup_price_data = dropdims(no_markup_price_data; dims = 5)
        end

        for subperiod in 1:num_subperiods
            reshaped_quantity = [Float64[] for bus in 1:num_buses]
            reshaped_price = [Float64[] for bus in 1:num_buses]
            if plot_no_markup_price
                reshaped_no_markup_price = [Float64[] for bus in 1:num_buses]
                # the second quantity is necessary because we will sort both vectors in increasing price order
                reshaped_no_markup_quantity = [Float64[] for bus in 1:num_buses]
            end

            for segment in 1:num_bid_segments
                for label_index in 1:num_labels
                    bus_index = _get_bus_index(quantity_metadata.labels[label_index], bus_label(inputs))
                    # mean across scenarios
                    quantity = mean(quantity_data[label_index, segment, subperiod, :])
                    price = mean(price_data[label_index, segment, subperiod, :])
                    # push point
                    push!(reshaped_quantity[bus_index], quantity)
                    push!(reshaped_price[bus_index], price)
                    if plot_no_markup_price
                        no_markup_price = mean(no_markup_price_data[label_index, segment, subperiod, :])
                        push!(reshaped_no_markup_price[bus_index], no_markup_price)
                        push!(reshaped_no_markup_quantity[bus_index], quantity)
                    end
                end
            end

            for bus in 1:num_buses
                sort_order = sortperm(reshaped_price[bus])
                reshaped_quantity[bus] = reshaped_quantity[bus][sort_order]
                reshaped_quantity[bus] = cumsum(reshaped_quantity[bus])
                reshaped_price[bus] = reshaped_price[bus][sort_order]
                if plot_no_markup_price
                    no_markup_sort_order = sortperm(reshaped_no_markup_price[bus])
                    reshaped_no_markup_quantity[bus] = reshaped_no_markup_quantity[bus][no_markup_sort_order]
                    reshaped_no_markup_quantity[bus] = cumsum(reshaped_no_markup_quantity[bus])
                    reshaped_no_markup_price[bus] = reshaped_no_markup_price[bus][no_markup_sort_order]
                end
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

            if plot_no_markup_price
                no_markup_quantity_data_to_plot = [Float64[0.0] for bus in 1:num_buses]
                no_markup_price_data_to_plot = [Float64[0.0] for bus in 1:num_buses]

                for bus in 1:num_buses
                    for (quantity, price) in zip(reshaped_no_markup_quantity[bus], reshaped_no_markup_price[bus])
                        # old point
                        push!(no_markup_quantity_data_to_plot[bus], no_markup_quantity_data_to_plot[bus][end])
                        push!(no_markup_price_data_to_plot[bus], price)
                        # new point
                        push!(no_markup_quantity_data_to_plot[bus], quantity)
                        push!(no_markup_price_data_to_plot[bus], price)
                    end
                end
            end

            configs = Vector{Config}()

            title = "Available Offers - Subperiod $subperiod"
            color_idx = 0
            for bus in 1:num_buses
                color_idx += 1
                push!(
                    configs,
                    Config(;
                        x = quantity_data_to_plot[bus],
                        y = price_data_to_plot[bus],
                        name = bus_label(inputs, bus),
                        line = Dict("color" => _get_plot_color(color_idx)),
                        type = "line",
                    ),
                )
                if plot_no_markup_price
                    color_idx += 1
                    push!(
                        configs,
                        Config(;
                            x = no_markup_quantity_data_to_plot[bus],
                            y = no_markup_price_data_to_plot[bus],
                            name = bus_label(inputs, bus) * " - Recommended Offer",
                            line = Dict("color" => _get_plot_color(color_idx)),
                            type = "line",
                        ),
                    )
                end
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
    number_of_demands = number_of_elements(inputs, DemandUnit)

    if isfile(demand_file)
        data, metadata = read_timeseries_file(demand_file)
        data = merge_period_subperiod(data)
        if read_ex_ante_demand_file(inputs)
            num_periods, num_scenarios, num_subperiods = metadata.dimension_size
            num_subscenarios = 1
            reshaped_data =
                Array{Float64, 3}(undef, metadata.number_of_time_series, num_periods * num_subperiods, num_subscenarios)
            # Use only first scenario
            reshaped_data[:, :, 1] = data[:, 1, :]
        else
            num_periods, num_scenarios, num_subscenarios, num_subperiods = metadata.dimension_size
            # Use only first scenario
            reshaped_data = data[:, :, 1, :]
        end
        if num_scenarios > 1
            @warn "Plotting demand for scenario 1 and ignoring the other scenarios. Total number of scenarios: $num_scenarios"
        end
    else
        num_periods = number_of_periods(inputs)
        num_subperiods = number_of_subperiods(inputs)
        num_subscenarios = 1
        reshaped_data = ones(number_of_demands, num_periods * num_subperiods, num_subscenarios)
    end

    configs = Vector{Config}()
    # Fix subscenario dimension with arbitrary value to get plot_ticks
    plot_ticks, hover_ticks =
        _get_plot_ticks(reshaped_data[:, 1, :], num_periods, initial_date_time(inputs), time_series_step(inputs))
    title = "Total demand"
    unit = "MW"
    color_idx = 0
    for d in 1:number_of_demands, subscenario in 1:num_subscenarios
        label = demand_unit_label(inputs, d) * " - Subscenario $subscenario"
        color_idx += 1
        push!(
            configs,
            Config(;
                x = 1:(num_periods*num_subperiods),
                y = reshaped_data[d, subscenario, :] * demand_unit_max_demand(inputs, d),
                name = label,
                line = Dict("color" => _get_plot_color(color_idx)),
                type = "line",
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
        yaxis = Dict("title" => "Demand [$unit]"),
    )

    _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "total_demand.html"))

    return nothing
end

function plot_asset_owner_output(
    inputs::AbstractInputs,
    file_path::String,
    plot_path::String,
    asset_owner_index::Int,
    title::String,
)
    data, metadata = read_timeseries_file(file_path)

    if :bid_segment in metadata.dimensions
        segment_index = findfirst(isequal(:bid_segment), metadata.dimensions)
        # the data array has dimensions in reverse order, and the first dimension is metadata.number_of_time_series, which is not in metadata.dimensions
        segment_index_in_data = length(metadata.dimensions) + 2 - segment_index
        data = dropdims(sum(data; dims = segment_index_in_data); dims = segment_index_in_data)
        metadata.dimension_size = metadata.dimension_size[1:end.!=segment_index]
    end

    if !(:subscenario in metadata.dimensions)
        @warn "Plotting asset owner outputs not implemented for ex-ante data."
        return nothing
    end

    num_periods, num_scenarios, num_subscenarios, num_subperiods = metadata.dimension_size
    if num_scenarios > 1 && asset_owner_index == first(index_of_elements(inputs, AssetOwner))
        @warn "Plotting asset owner total profit for scenario 1 and ignoring the other scenarios. Total number of scenarios: $num_scenarios"
    end
    @assert num_periods == 1 "Total profit plot only implemented for single period run mode. Number of periods: $num_periods"

    labels_to_read = String[]
    for bg in bidding_group_label(inputs)[bidding_group_asset_owner_index(inputs).==asset_owner_index]
        for bus in bus_label(inputs)
            push!(labels_to_read, "$bg - $bus")
        end
    end
    # If the asset owner has no bidding groups, there is no profit to plot
    if isempty(labels_to_read)
        return nothing
    end
    indexes_to_read = [findfirst(isequal(label), metadata.labels) for label in labels_to_read]

    # Fixed scenario, fixed period, sum for all bidding groups
    reshaped_data = dropdims(sum(data[indexes_to_read, :, :, 1, 1]; dims = 1); dims = 1)

    configs = Vector{Config}()

    if num_subperiods == 1
        push!(
            configs,
            Config(;
                x = 1:num_subscenarios,
                y = reshaped_data[1, :],
                name = "",
                line = Dict("color" => _get_plot_color(1)),
                type = "bar",
            ),
        )

        main_configuration = Config(;
            title = title,
            xaxis = Dict(
                "title" => "Subscenario",
                "tickmode" => "array",
                "tickvals" => 1:num_subscenarios,
                "ticktext" => string.(1:num_subscenarios),
            ),
            yaxis = Dict("title" => "[$(metadata.unit)]"),
        )
    else
        for subscenario in 1:num_subscenarios
            push!(
                configs,
                Config(;
                    x = 1:num_subperiods,
                    y = reshaped_data[:, subscenario],
                    name = "Subscenario $subscenario",
                    line = Dict("color" => _get_plot_color(subscenario)),
                    type = "line",
                ),
            )
        end

        main_configuration = Config(;
            title = title,
            xaxis = Dict(
                "title" => "Subperiod",
                "tickmode" => "array",
                "tickvals" => 1:num_subperiods,
                "ticktext" => string.(1:num_subperiods),
            ),
            yaxis = Dict("title" => "[$(metadata.unit)]"),
        )
    end

    _save_plot(Plot(configs, main_configuration), plot_path)

    return nothing
end

function plot_asset_owner_sum_output(
    inputs::AbstractInputs,
    file_path::String,
    plot_path::String,
    title::String,
)
    data, metadata = read_timeseries_file(file_path)

    if :bid_segment in metadata.dimensions
        segment_index = findfirst(isequal(:bid_segment), metadata.dimensions)
        # the data array has dimensions in reverse order, and the first dimension is metadata.number_of_time_series, which is not in metadata.dimensions
        segment_index_in_data = length(metadata.dimensions) + 2 - segment_index
        data = dropdims(sum(data; dims = segment_index_in_data); dims = segment_index_in_data)
        metadata.dimension_size = metadata.dimension_size[1:end.!=segment_index]
    end

    num_periods, num_scenarios, num_subscenarios, num_subperiods = metadata.dimension_size
    if num_scenarios > 1
        @warn "Plotting total profit for scenario 1 and ignoring the other scenarios. Total number of scenarios: $num_scenarios"
    end
    @assert num_periods == 1 "Total profit plot only implemented for single period run mode. Number of periods: $num_periods"

    asset_onwer_indexes = index_of_elements(inputs, AssetOwner)
    reshaped_data = Array{Float64, 3}(undef, length(asset_onwer_indexes), num_subperiods, num_subscenarios)

    for (i, asset_owner_index) in enumerate(asset_onwer_indexes)
        labels_to_read = String[]
        for bg in bidding_group_label(inputs)[bidding_group_asset_owner_index(inputs).==asset_owner_index]
            for bus in bus_label(inputs)
                push!(labels_to_read, "$bg - $bus")
            end
        end
        indexes_to_read = [findfirst(isequal(label), metadata.labels) for label in labels_to_read]

        # Fixed scenario, fixed period, sum for the asset owner's bidding groups
        reshaped_data[i, :, :] = dropdims(sum(data[indexes_to_read, :, :, 1, 1]; dims = 1); dims = 1)
    end

    if num_subperiods == 1
        configs = Vector{Config}()
        for asset_owner_index in asset_onwer_indexes
            ao_label = asset_owner_label(inputs, asset_owner_index)
            push!(
                configs,
                Config(;
                    x = 1:num_subscenarios,
                    y = reshaped_data[asset_owner_index, 1, :],
                    name = ao_label,
                    line = Dict("color" => _get_plot_color(asset_owner_index)),
                    type = "bar",
                ),
            )
        end

        main_configuration = Config(;
            title = title,
            xaxis = Dict(
                "title" => "Subscenario",
                "tickmode" => "array",
                "tickvals" => 1:num_subscenarios,
                "ticktext" => string.(1:num_subscenarios),
            ),
            yaxis = Dict("title" => metadata.unit),
        )

        _save_plot(Plot(configs, main_configuration), plot_path * ".html")
    else
        for subscenario in 1:num_subscenarios
            configs = Vector{Config}()
            for asset_owner_index in asset_onwer_indexes
                ao_label = asset_owner_label(inputs, asset_owner_index)
                push!(
                    configs,
                    Config(;
                        x = 1:num_subperiods,
                        y = reshaped_data[asset_owner_index, :, subscenario],
                        name = ao_label,
                        line = Dict("color" => _get_plot_color(asset_owner_index)),
                        type = "line",
                    ),
                )
            end

            main_configuration = Config(;
                title = title * " - Subscenario $subscenario",
                xaxis = Dict(
                    "title" => "Subperiod",
                    "tickmode" => "array",
                    "tickvals" => 1:num_subperiods,
                    "ticktext" => string.(1:num_subperiods),
                ),
                yaxis = Dict("title" => metadata.unit),
            )

            _save_plot(Plot(configs, main_configuration), plot_path * "_subscenario_$subscenario.html")
        end
    end

    return nothing
end

function plot_ui_timeseries(;
    file_path::String,
    plot_path::String,
    title::String,
    agent_labels::Vector{String} = String[],
    stack::Bool = false,
)
    data, metadata = read_timeseries_file(file_path)

    if isempty(agent_labels)
        agent_labels = String.(metadata.labels)
        number_of_agents = length(agent_labels)
        agent_indexes = 1:number_of_agents
    else
        number_of_agents = length(agent_labels)
        agent_indexes = [findfirst(isequal(agent), metadata.labels) for agent in agent_labels]
    end

    has_subscenarios = :subscenario in metadata.dimensions

    if has_subscenarios
        @assert metadata.dimensions == [:period, :scenario, :subscenario, :subperiod] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
        num_periods, num_scenarios, num_subscenarios, num_subperiods = metadata.dimension_size
        reshaped_data = data[agent_indexes, :, :, 1, 1]
    else
        @assert metadata.dimensions == [:period, :scenario, :subperiod] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
        num_periods, num_scenarios, num_subperiods = metadata.dimension_size
        num_subscenarios = 1
        reshaped_data = Array{Float64, 3}(undef, number_of_agents, num_subperiods, num_subscenarios)
        reshaped_data[:, :, 1] = data[agent_indexes, :, 1, 1]
    end
    if num_scenarios > 1
        @warn "Plotting $title for scenario 1 and ignoring the other scenarios. Total number of scenarios: $num_scenarios"
    end
    @assert num_periods == 1 "$title plot only implemented for single period run mode. Number of periods: $num_periods"

    configs = Vector{Config}()
    color_idx = 0

    plot_kwargs = if stack
        Dict(
            :mode => "lines+markers",
            :stackgroup => "one",
        )
    else
        Dict()
    end

    if num_subperiods == 1
        plot_ticks = ["$i" for i in 1:num_subscenarios]
        hover_ticks = ["Subscenario $i" for i in 1:num_subscenarios]
        for agent in 1:number_of_agents
            label = agent_labels[agent]
            color_idx += 1
            push!(
                configs,
                Config(;
                    x = 1:num_subscenarios,
                    y = reshaped_data[agent, 1, :],
                    name = label,
                    line = Dict("color" => _get_plot_color(color_idx)),
                    type = "bar",
                    text = hover_ticks,
                    hovertemplate = "%{y} $(metadata.unit)<br>%{text}",
                    plot_kwargs...,
                ),
            )
        end
        main_configuration = Config(;
            title = title,
            xaxis = Dict(
                "title" => "Subscenario",
                "tickmode" => "array",
                "tickvals" => 1:num_subscenarios,
                "ticktext" => plot_ticks,
            ),
            yaxis = Dict("title" => metadata.unit),
        )
    else
        plot_ticks = ["$i" for i in 1:num_subperiods]
        hover_ticks = ["Subperiod $i" for i in 1:num_subperiods]
        for agent in 1:number_of_agents, subscenario in 1:num_subscenarios
            label = agent_labels[agent] * " - Subscenario $subscenario"
            color_idx += 1
            push!(
                configs,
                Config(;
                    x = 1:num_subperiods,
                    y = reshaped_data[agent, :, subscenario],
                    name = label,
                    line = Dict("color" => _get_plot_color(color_idx)),
                    type = "line",
                    text = hover_ticks,
                    hovertemplate = "%{y} $(metadata.unit)<br>%{text}",
                    plot_kwargs...,
                ),
            )
        end
        main_configuration = Config(;
            title = title,
            xaxis = Dict(
                "title" => "Subperiod",
                "tickmode" => "array",
                "tickvals" => 1:num_subperiods,
                "ticktext" => plot_ticks,
            ),
            yaxis = Dict("title" => metadata.unit),
        )
    end

    _save_plot(Plot(configs, main_configuration), plot_path * ".html")

    return nothing
end
