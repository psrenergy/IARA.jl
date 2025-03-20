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

function build_ui_operator_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots", "operator")
    mkdir(plots_path)

    # Profit
    profit_file_path = get_profit_file(inputs)
    plot_path = joinpath(plots_path, "total_profit")
    plot_operator_output(inputs, profit_file_path, plot_path, get_name(inputs, "total_profit"); round_data = true)

    # Revenue
    revenue_files = get_revenue_files(inputs)
    if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        @assert length(revenue_files) == 2
        plot_path = joinpath(plots_path, "total_revenue_ex_ante")
        plot_operator_output(
            inputs,
            revenue_files[1],
            plot_path,
            get_name(inputs, "ex_ante_revenue");
            round_data = true,
            ex_ante_plot = true,
        )
        plot_path = joinpath(plots_path, "total_revenue_ex_post")
        plot_operator_output(
            inputs,
            revenue_files[2],
            plot_path,
            get_name(inputs, "ex_post_revenue");
            round_data = true,
        )
    else
        @assert length(revenue_files) == 1
        plot_path = joinpath(plots_path, "total_revenue")
        plot_operator_output(inputs, revenue_files[1], plot_path, get_name(inputs, "total_revenue"); round_data = true)
    end

    # Generation
    generation_files = get_generation_files(inputs)
    if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        @assert length(generation_files) == 2
        plot_path = joinpath(plots_path, "total_generation_ex_ante")
        plot_operator_output(
            inputs,
            generation_files[1],
            plot_path,
            get_name(inputs, "ex_ante_generation");
            ex_ante_plot = true,
        )
        plot_path = joinpath(plots_path, "total_generation_ex_post")
        plot_operator_output(inputs, generation_files[2], plot_path, get_name(inputs, "ex_post_generation"))
    else
        @assert length(generation_files) == 1
        plot_path = joinpath(plots_path, "total_generation")
        plot_operator_output(inputs, generation_files[1], plot_path, get_name(inputs, "total_generation"))
    end

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
            title = "$ao_label - $(get_name(inputs, "total_profit"))"
            plot_path = joinpath(plots_path, "profit_$ao_label.html")
            plot_agent_output(inputs, profit_file_path, plot_path, asset_owner_index, title; round_data = true)
        end
    end

    # Revenue
    revenue_files = get_revenue_files(inputs)
    if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        @assert length(revenue_files) == 2
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "ex_ante_revenue"))"
            plot_path = joinpath(plots_path, "revenue_ex_ante_$ao_label.html")
            plot_agent_output(
                inputs,
                revenue_files[1],
                plot_path,
                asset_owner_index,
                title;
                round_data = true,
                ex_ante_plot = true,
            )
        end
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "ex_post_revenue"))"
            plot_path = joinpath(plots_path, "revenue_ex_post_$ao_label.html")
            plot_agent_output(inputs, revenue_files[2], plot_path, asset_owner_index, title; round_data = true)
        end
    else
        @assert length(revenue_files) == 1
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "total_revenue"))"
            plot_path = joinpath(plots_path, "revenue_$ao_label.html")
            plot_agent_output(inputs, revenue_files[1], plot_path, asset_owner_index, title; round_data = true)
        end
    end

    # Generation
    generation_files = get_generation_files(inputs)
    if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        @assert length(generation_files) == 2
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "ex_ante_generation"))"
            plot_path = joinpath(plots_path, "generation_ex_ante_$ao_label.html")
            plot_agent_output(inputs, generation_files[1], plot_path, asset_owner_index, title; ex_ante_plot = true)
        end
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "ex_post_generation"))"
            plot_path = joinpath(plots_path, "generation_ex_post_$ao_label.html")
            plot_agent_output(inputs, generation_files[2], plot_path, asset_owner_index, title)
        end
    else
        @assert length(generation_files) == 1
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "total_generation"))"
            plot_path = joinpath(plots_path, "generation_$ao_label.html")
            plot_agent_output(inputs, generation_files[1], plot_path, asset_owner_index, title)
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
    files = get_load_marginal_cost_files(inputs)
    if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        @assert length(files) == 2
        plot_general_output(
            inputs;
            file_path = files[1],
            plot_path = joinpath(plots_path, "spot_price_ex_ante"),
            title = get_name(inputs, "ex_ante_spot_price"),
            round_data = true,
            ex_ante_plot = true,
        )
        plot_general_output(
            inputs;
            file_path = files[2],
            plot_path = joinpath(plots_path, "spot_price_ex_post"),
            title = get_name(inputs, "ex_post_spot_price"),
            round_data = true,
        )
    else
        @assert length(files) == 1
        plot_general_output(
            inputs;
            file_path = files[1],
            plot_path = joinpath(plots_path, "spot_price"),
            title = get_name(inputs, "spot_price"),
            round_data = true,
        )
    end

    # Generation by technology
    generation_file_path = joinpath(post_processing_path(inputs), "generation.csv")
    if isfile(generation_file_path)
        # Generation
        plot_general_output(
            inputs;
            file_path = generation_file_path,
            plot_path = joinpath(plots_path, "generation_by_technology"),
            title = get_name(inputs, "generation_by_technology"),
            agent_labels = ["hydro", "thermal", "renewable", "battery_unit"], # Does not include deficit
            stack = true,
        )
        # Deficit
        plot_general_output(
            inputs;
            file_path = generation_file_path,
            plot_path = joinpath(plots_path, "deficit"),
            title = get_name(inputs, "deficit"),
            agent_labels = ["deficit"],
        )
    end

    # Offer curve
    plot_offer_curve(inputs, plots_path)

    return nothing
end

function plot_offer_curve(inputs::AbstractInputs, plots_path::String)
    offer_files = get_offer_file_paths(inputs)
    if !isempty(offer_files)
        plot_no_markup_price = false
        quantity_offer_file = offer_files[1]
        price_offer_file = offer_files[2]
        if length(offer_files) == 4
            no_markup_price_offer_file = offer_files[3]
            no_markup_quantity_offer_file = offer_files[4]
            plot_no_markup_price = true
        end

        quantity_data, quantity_metadata = read_timeseries_file(quantity_offer_file)
        price_data, price_metadata = read_timeseries_file(price_offer_file)
        if plot_no_markup_price
            no_markup_price_data, no_markup_price_metadata = read_timeseries_file(no_markup_price_offer_file)
            no_markup_quantity_data, no_markup_quantity_metadata = read_timeseries_file(no_markup_quantity_offer_file)
        end

        @assert quantity_metadata.number_of_time_series == price_metadata.number_of_time_series "Mismatch between quantity and price offer file columns"
        @assert quantity_metadata.dimension_size == price_metadata.dimension_size "Mismatch between quantity and price offer file dimensions"
        @assert quantity_metadata.labels == price_metadata.labels "Mismatch between quantity and price offer file labels"
        if plot_no_markup_price
            # Compare the price files
            @assert no_markup_price_metadata.number_of_time_series == price_metadata.number_of_time_series "Mismatch between reference price and price offer file columns"
            # The number of periods in the reference price file is always 1
            # The number of bid segments does not need to match
            @assert no_markup_price_metadata.dimension_size[2:end-1] == price_metadata.dimension_size[2:end-1] "Mismatch between reference price and price offer file dimensions"
            @assert sort(no_markup_price_metadata.labels) == sort(price_metadata.labels) "Mismatch between reference price and price offer file labels"
            # Compare both "no_markup" files
            @assert no_markup_price_metadata.number_of_time_series == no_markup_quantity_metadata.number_of_time_series "Mismatch between reference price and reference quantity offer file columns"
            @assert no_markup_price_metadata.dimension_size == no_markup_quantity_metadata.dimension_size "Mismatch between reference price and reference quantity offer file dimensions"
            @assert no_markup_price_metadata.labels == no_markup_quantity_metadata.labels "Mismatch between reference price and reference quantity offer file labels"
        end

        num_labels = quantity_metadata.number_of_time_series
        num_periods, num_scenarios, num_subperiods, num_bid_segments = quantity_metadata.dimension_size
        num_buses = number_of_elements(inputs, Bus)

        if plot_no_markup_price
            num_bid_segments_no_markup = no_markup_price_metadata.dimension_size[end]
        end

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
            no_markup_quantity_data = dropdims(no_markup_quantity_data; dims = 5)
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
                end
            end

            if plot_no_markup_price
                for segment in 1:num_bid_segments_no_markup
                    for label_index in 1:num_labels
                        bus_index = _get_bus_index(quantity_metadata.labels[label_index], bus_label(inputs))
                        # mean across scenarios
                        no_markup_price = mean(no_markup_price_data[label_index, segment, subperiod, :])
                        no_markup_quantity = mean(no_markup_quantity_data[label_index, segment, subperiod, :])
                        # push point
                        push!(reshaped_no_markup_price[bus_index], no_markup_price)
                        push!(reshaped_no_markup_quantity[bus_index], no_markup_quantity)
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

            title = get_name(inputs, "available_offers")
            if num_subperiods > 1
                title *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end
            color_idx = 0
            for bus in 1:num_buses
                color_idx += 1
                name = get_name(inputs, "offers")
                if num_buses > 1
                    name *= " - $(bus_label(inputs, bus))"
                end
                push!(
                    configs,
                    Config(;
                        x = quantity_data_to_plot[bus],
                        y = price_data_to_plot[bus],
                        name = name,
                        line = Dict("color" => _get_plot_color(color_idx)),
                        type = "line",
                    ),
                )
                if plot_no_markup_price
                    color_idx += 1
                    name = get_name(inputs, "operating_cost")
                    if num_buses > 1
                        name *= " - $(bus_label(inputs, bus))"
                    end
                    push!(
                        configs,
                        Config(;
                            x = no_markup_quantity_data_to_plot[bus],
                            y = no_markup_price_data_to_plot[bus],
                            name = name,
                            line = Dict("color" => _get_plot_color(color_idx)),
                            type = "line",
                        ),
                    )
                end
            end

            # Add demand lines
            ex_ante_demand, ex_post_demand = get_demands_to_plot(inputs)
            demand_name = "demand"
            if any_elements(inputs, RenewableUnit; filters = [has_no_bidding_group])
                ex_ante_generation, ex_post_generation = get_renewable_generation_to_plot(inputs)
                ex_ante_demand = ex_ante_demand .- ex_ante_generation
                ex_post_demand = ex_post_demand .- ex_post_generation
                demand_name = "net_demand"
            end
            ex_post_min_demand = dropdims(minimum(ex_post_demand; dims = 1); dims = 1)
            ex_post_max_demand = dropdims(maximum(ex_post_demand; dims = 1); dims = 1)
            demand_time_index = (inputs.args.period - 1) * num_subperiods + subperiod
            y_axis_limits = [minimum(minimum.(price_data_to_plot)), maximum(maximum.(price_data_to_plot))] .* 1.1
            y_axis_range = range(y_axis_limits[1], y_axis_limits[2]; length = 100)
            # Ex-post min demand
            color_idx += 1
            push!(
                configs,
                Config(;
                    x = range(
                        ex_post_min_demand[demand_time_index],
                        ex_post_min_demand[demand_time_index];
                        length = 100,
                    ),
                    y = y_axis_range,
                    name = get_name(inputs, "minimum_$demand_name"),
                    line = Dict("color" => _get_plot_color(color_idx), "dash" => "dash"),
                    type = "line",
                    mode = "lines",
                    hovertemplate = "%{x} MWh",
                ),
            )
            # Ex-ante demand
            color_idx += 1
            push!(
                configs,
                Config(;
                    x = range(ex_ante_demand[demand_time_index], ex_ante_demand[demand_time_index]; length = 100),
                    y = y_axis_range,
                    name = get_name(inputs, "average_$demand_name"),
                    line = Dict("color" => _get_plot_color(color_idx), "dash" => "dash"),
                    type = "line",
                    mode = "lines",
                    hovertemplate = "%{x} MWh",
                ),
            )
            # Ex-post max demand
            color_idx += 1
            push!(
                configs,
                Config(;
                    x = range(
                        ex_post_max_demand[demand_time_index],
                        ex_post_max_demand[demand_time_index];
                        length = 100,
                    ),
                    y = y_axis_range,
                    name = get_name(inputs, "maximum_$demand_name"),
                    line = Dict("color" => _get_plot_color(color_idx), "dash" => "dash"),
                    type = "line",
                    mode = "lines",
                    hovertemplate = "%{x} MWh",
                ),
            )

            main_configuration = Config(;
                title = title,
                xaxis = Dict("title" => "$(get_name(inputs, "quantity")) [MWh]"),
                yaxis = Dict("title" => "$(get_name(inputs, "price")) [\$/MWh]"),
            )

            _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "offer_curve_subperiod_$subperiod.html"))
        end
    end

    return nothing
end

function plot_agent_output(
    inputs::AbstractInputs,
    file_path::String,
    plot_path::String,
    asset_owner_index::Int,
    title::String;
    subperiod_on_x_axis::Bool = false,
    round_data::Bool = false,
    ex_ante_plot::Bool = false,
)
    data, metadata = read_timeseries_file(file_path)

    if :bid_segment in metadata.dimensions
        segment_index = findfirst(isequal(:bid_segment), metadata.dimensions)
        # The data array has dimensions in reverse order, and the first dimension is metadata.number_of_time_series, which is not in metadata.dimensions
        segment_index_in_data = length(metadata.dimensions) + 2 - segment_index
        data = dropdims(sum(data; dims = segment_index_in_data); dims = segment_index_in_data)
        metadata.dimension_size = metadata.dimension_size[1:end.!=segment_index]
        metadata.dimensions = metadata.dimensions[1:end.!=segment_index]
    end

    if occursin("generation", file_path)
        convert_generation_data_from_GWh_to_MW!(data, metadata, inputs)
    end

    has_subscenarios = :subscenario in metadata.dimensions

    if has_subscenarios
        @assert metadata.dimensions == [:period, :scenario, :subscenario, :subperiod] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
        num_periods, num_scenarios, num_subscenarios, num_subperiods = metadata.dimension_size
        reshaped_data = data[:, :, :, 1, 1]
    else
        @assert metadata.dimensions == [:period, :scenario, :subperiod] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
        num_periods, num_scenarios, num_subperiods = metadata.dimension_size
        num_subscenarios = 1
        reshaped_data = Array{Float64, 3}(undef, metadata.number_of_time_series, num_subperiods, num_subscenarios)
        reshaped_data[:, :, 1] = data[:, :, 1, 1]
    end

    if num_scenarios > 1 && asset_owner_index == first(index_of_elements(inputs, AssetOwner))
        @warn "Plotting asset owner $title for scenario 1 and ignoring the other scenarios. Total number of scenarios: $num_scenarios"
    end
    @assert num_periods == 1 "$title plot only implemented for single period run mode. Number of periods: $num_periods"

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

    if round_data
        reshaped_data = round.(reshaped_data; digits = 1)
    end

    if subperiod_on_x_axis && num_subperiods != 1
        for subscenario in 1:num_subscenarios
            push!(
                configs,
                Config(;
                    x = 1:num_subperiods,
                    y = reshaped_data[:, subscenario],
                    name = "$(get_name(inputs, "subscenario")) $subscenario",
                    line = Dict("color" => _get_plot_color(subscenario)),
                    type = "line",
                ),
            )
        end

        main_configuration = Config(;
            title = title,
            xaxis = Dict(
                "title" => get_name(inputs, "subperiod"),
                "tickmode" => "array",
                "tickvals" => 1:num_subperiods,
                "ticktext" => string.(1:num_subperiods),
            ),
            yaxis = Dict("title" => "$(metadata.unit)"),
        )
    else
        for subperiod in 1:num_subperiods
            push!(
                configs,
                Config(;
                    x = 1:num_subscenarios,
                    y = reshaped_data[subperiod, :],
                    name = "$(get_name(inputs, "subperiod")) $subperiod",
                    line = Dict("color" => _get_plot_color(subperiod)),
                    type = "bar",
                ),
            )
        end

        if ex_ante_plot
            x_axis_title = ""
            x_axis_tickvals = []
            x_axis_ticktext = []
        else
            # This is actually the subscenario, with a simplified name for UI cases
            x_axis_title = get_name(inputs, "scenario")
            x_axis_tickvals = 1:num_subscenarios
            x_axis_ticktext = string.(1:num_subscenarios)
        end
        main_configuration = Config(;
            title = title,
            xaxis = Dict(
                "title" => x_axis_title,
                "tickmode" => "array",
                "tickvals" => x_axis_tickvals,
                "ticktext" => x_axis_ticktext,
            ),
            yaxis = Dict("title" => "$(metadata.unit)"),
        )
    end

    _save_plot(Plot(configs, main_configuration), plot_path)

    return nothing
end

function plot_operator_output(
    inputs::AbstractInputs,
    file_path::String,
    plot_path::String,
    title::String;
    subperiod_on_x_axis::Bool = false,
    round_data::Bool = false,
    ex_ante_plot::Bool = false,
)
    data, metadata = read_timeseries_file(file_path)

    if :bid_segment in metadata.dimensions
        segment_index = findfirst(isequal(:bid_segment), metadata.dimensions)
        # the data array has dimensions in reverse order, and the first dimension is metadata.number_of_time_series, which is not in metadata.dimensions
        segment_index_in_data = length(metadata.dimensions) + 2 - segment_index
        data = dropdims(sum(data; dims = segment_index_in_data); dims = segment_index_in_data)
        metadata.dimension_size = metadata.dimension_size[1:end.!=segment_index]
        metadata.dimensions = metadata.dimensions[1:end.!=segment_index]
    end

    if occursin("generation", file_path)
        convert_generation_data_from_GWh_to_MW!(data, metadata, inputs)
    end

    has_subscenarios = :subscenario in metadata.dimensions

    if has_subscenarios
        @assert metadata.dimensions == [:period, :scenario, :subscenario, :subperiod] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
        num_periods, num_scenarios, num_subscenarios, num_subperiods = metadata.dimension_size
        reshaped_data = data[:, :, :, 1, 1]
    else
        @assert metadata.dimensions == [:period, :scenario, :subperiod] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
        num_periods, num_scenarios, num_subperiods = metadata.dimension_size
        num_subscenarios = 1
        reshaped_data = Array{Float64, 3}(undef, metadata.number_of_time_series, num_subperiods, num_subscenarios)
        reshaped_data[:, :, 1] = data[:, :, 1, 1]
    end

    if num_scenarios > 1
        @warn "Plotting $title for scenario 1 and ignoring the other scenarios. Total number of scenarios: $num_scenarios"
    end
    @assert num_periods == 1 "$title plot only implemented for single period run mode. Number of periods: $num_periods"

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

    if round_data
        reshaped_data = round.(reshaped_data; digits = 1)
    end

    if subperiod_on_x_axis && num_subperiods != 1
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
                title = title * " - $(get_name(inputs, "subscenario")) $subscenario",
                xaxis = Dict(
                    "title" => get_name(inputs, "subperiod"),
                    "tickmode" => "array",
                    "tickvals" => 1:num_subperiods,
                    "ticktext" => string.(1:num_subperiods),
                ),
                yaxis = Dict("title" => metadata.unit),
            )

            _save_plot(Plot(configs, main_configuration), plot_path * "_subscenario_$subscenario.html")
        end
    else
        for subperiod in 1:num_subperiods
            configs = Vector{Config}()
            for asset_owner_index in asset_onwer_indexes
                ao_label = asset_owner_label(inputs, asset_owner_index)
                push!(
                    configs,
                    Config(;
                        x = 1:num_subscenarios,
                        y = reshaped_data[asset_owner_index, subperiod, :],
                        name = ao_label,
                        line = Dict("color" => _get_plot_color(asset_owner_index)),
                        type = "bar",
                    ),
                )
            end

            if ex_ante_plot
                x_axis_title = ""
                x_axis_tickvals = []
                x_axis_ticktext = []
            else
                # This is actually the subscenario, with a simplified name for UI cases
                x_axis_title = get_name(inputs, "scenario")
                x_axis_tickvals = 1:num_subscenarios
                x_axis_ticktext = string.(1:num_subscenarios)
            end
            plot_title = title
            if num_subperiods > 1
                plot_title *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end
            main_configuration = Config(;
                title = plot_title,
                xaxis = Dict(
                    "title" => x_axis_title,
                    "tickmode" => "array",
                    "tickvals" => x_axis_tickvals,
                    "ticktext" => x_axis_ticktext,
                ),
                yaxis = Dict("title" => "$(metadata.unit)"),
            )

            _save_plot(Plot(configs, main_configuration), plot_path * "_subperiod_$subperiod.html")
        end
    end

    return nothing
end

function plot_general_output(
    inputs::AbstractInputs;
    file_path::String,
    plot_path::String,
    title::String,
    agent_labels::Vector{String} = String[],
    stack::Bool = false,
    subperiod_on_x_axis::Bool = false,
    round_data::Bool = false,
    ex_ante_plot::Bool = false,
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

    if occursin("generation", file_path)
        convert_generation_data_from_GWh_to_MW!(data, metadata, inputs)
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

    if round_data
        reshaped_data = round.(reshaped_data; digits = 1)
    end

    if subperiod_on_x_axis && num_subperiods != 1
        for agent in 1:number_of_agents, subscenario in 1:num_subscenarios
            label = agent_labels[agent] * " - $(get_name(inputs, "subscenario")) $subscenario"
            color_idx += 1
            push!(
                configs,
                Config(;
                    x = 1:num_subperiods,
                    y = reshaped_data[agent, :, subscenario],
                    name = label,
                    line = Dict("color" => _get_plot_color(color_idx)),
                    type = "line",
                    plot_kwargs...,
                ),
            )
        end
        main_configuration = Config(;
            title = title,
            xaxis = Dict(
                "title" => get_name(inputs, "subperiod"),
                "tickmode" => "array",
                "tickvals" => 1:num_subperiods,
                "ticktext" => string(1:num_subperiods),
            ),
            yaxis = Dict("title" => metadata.unit),
        )
    else
        for agent in 1:number_of_agents, subperiod in 1:num_subperiods
            label = agent_labels[agent]
            if num_subperiods > 1
                label *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end
            color_idx += 1
            push!(
                configs,
                Config(;
                    x = 1:num_subscenarios,
                    y = reshaped_data[agent, subperiod, :],
                    name = label,
                    line = Dict("color" => _get_plot_color(color_idx)),
                    type = "bar",
                    plot_kwargs...,
                ),
            )
        end

        if ex_ante_plot
            x_axis_title = ""
            x_axis_tickvals = []
            x_axis_ticktext = []
        else
            # This is actually the subscenario, with a simplified name for UI cases
            x_axis_title = get_name(inputs, "scenario")
            x_axis_tickvals = 1:num_subscenarios
            x_axis_ticktext = string.(1:num_subscenarios)
        end
        main_configuration = Config(;
            title = title,
            xaxis = Dict(
                "title" => x_axis_title,
                "tickmode" => "array",
                "tickvals" => x_axis_tickvals,
                "ticktext" => x_axis_ticktext,
            ),
            yaxis = Dict("title" => "$(metadata.unit)"),
        )
    end

    _save_plot(Plot(configs, main_configuration), plot_path * ".html")

    return nothing
end
