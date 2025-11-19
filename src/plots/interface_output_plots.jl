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
    plot_virtual_reservoir_results = any_elements(inputs, VirtualReservoir)

    # Revenue
    revenue_files = get_revenue_files(inputs)
    vr_revenue_files = if plot_virtual_reservoir_results
        get_virtual_reservoir_revenue_files(inputs)
    else
        ["" for _ in revenue_files]
    end
    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
        @assert length(revenue_files) == 2
        plot_path = joinpath(plots_path, "total_revenue_ex_ante")
        plot_operator_output(
            inputs,
            revenue_files[1],
            plot_path,
            get_name(inputs, "ex_ante_revenue");
            round_data = true,
            ex_ante_plot = true,
            vr_file_path = vr_revenue_files[1],
        )
        plot_path = joinpath(plots_path, "total_revenue_ex_post")
        plot_operator_output(
            inputs,
            revenue_files[2],
            plot_path,
            get_name(inputs, "ex_post_revenue");
            round_data = true,
            vr_file_path = vr_revenue_files[2],
        )
    else
        @assert length(revenue_files) == 1
        plot_path = joinpath(plots_path, "total_revenue")
        plot_operator_output(
            inputs,
            revenue_files[1],
            plot_path,
            get_name(inputs, "total_revenue");
            round_data = true,
            vr_file_path = vr_revenue_files[1],
        )
    end

    # Generation
    generation_files = get_generation_files(inputs)
    vr_generation_files = if plot_virtual_reservoir_results
        get_virtual_reservoir_generation_files(inputs)
    else
        ["" for _ in generation_files]
    end
    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
        @assert length(generation_files) == 2
        plot_path = joinpath(plots_path, "total_generation_ex_ante")
        plot_operator_output(
            inputs,
            generation_files[1],
            plot_path,
            get_name(inputs, "ex_ante_generation");
            ex_ante_plot = true,
            vr_file_path = vr_generation_files[1],
        )
        plot_path = joinpath(plots_path, "total_generation_ex_post")
        plot_operator_output(
            inputs,
            generation_files[2],
            plot_path,
            get_name(inputs, "ex_post_generation");
            vr_file_path = vr_generation_files[2],
        )
    else
        @assert length(generation_files) == 1
        plot_path = joinpath(plots_path, "total_generation")
        plot_operator_output(
            inputs,
            generation_files[1],
            plot_path,
            get_name(inputs, "total_generation");
            vr_file_path = vr_generation_files[1],
        )
    end

    return nothing
end

function build_ui_agents_plots(
    inputs::Inputs;
)
    plots_path = joinpath(output_path(inputs), "plots", "agents")
    mkdir(plots_path)
    plot_virtual_reservoir_results = any_elements(inputs, VirtualReservoir)

    # Profit
    profit_file_path = get_profit_file(inputs)
    vr_profit_file_path = if plot_virtual_reservoir_results
        get_virtual_reservoir_profit_file(inputs)
    else
        ""
    end
    if isfile(profit_file_path)
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "total_profit"))"
            plot_path = joinpath(plots_path, "profit_$ao_label.html")
            plot_agent_output(
                inputs,
                profit_file_path,
                plot_path,
                asset_owner_index,
                title;
                round_data = true,
                vr_file_path = vr_profit_file_path,
            )
        end
    end

    # Revenue
    revenue_files = get_revenue_files(inputs)
    vr_revenue_files = if plot_virtual_reservoir_results
        get_virtual_reservoir_revenue_files(inputs)
    else
        ["" for _ in revenue_files]
    end
    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
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
                vr_file_path = vr_revenue_files[1],
            )
        end
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "ex_post_revenue"))"
            plot_path = joinpath(plots_path, "revenue_ex_post_$ao_label.html")
            plot_agent_output(
                inputs,
                revenue_files[2],
                plot_path,
                asset_owner_index,
                title;
                round_data = true,
                vr_file_path = vr_revenue_files[2],
            )
        end
    else
        @assert length(revenue_files) == 1
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "total_revenue"))"
            plot_path = joinpath(plots_path, "revenue_$ao_label.html")
            plot_agent_output(
                inputs,
                revenue_files[1],
                plot_path,
                asset_owner_index,
                title;
                round_data = true,
                vr_file_path = vr_revenue_files[1],
            )
        end
    end

    # Generation
    generation_files = get_generation_files(inputs)
    vr_generation_files = if plot_virtual_reservoir_results
        get_virtual_reservoir_generation_files(inputs)
    else
        ["" for _ in generation_files]
    end
    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
        @assert length(generation_files) == 2
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "ex_ante_generation"))"
            plot_path = joinpath(plots_path, "generation_ex_ante_$ao_label.html")
            plot_agent_output(
                inputs,
                generation_files[1],
                plot_path,
                asset_owner_index,
                title;
                ex_ante_plot = true,
                vr_file_path = vr_generation_files[1],
            )
        end
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "ex_post_generation"))"
            plot_path = joinpath(plots_path, "generation_ex_post_$ao_label.html")
            plot_agent_output(
                inputs,
                generation_files[2],
                plot_path,
                asset_owner_index,
                title;
                vr_file_path = vr_generation_files[2],
            )
        end
    else
        @assert length(generation_files) == 1
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "total_generation"))"
            plot_path = joinpath(plots_path, "generation_$ao_label.html")
            plot_agent_output(
                inputs,
                generation_files[1],
                plot_path,
                asset_owner_index,
                title;
                vr_file_path = vr_generation_files[1],
            )
        end
    end

    # Costs
    cost_file_path = get_variable_cost_file(inputs)
    if isfile(cost_file_path)
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "total_cost"))"
            plot_path = joinpath(plots_path, "cost_$ao_label.html")
            plot_agent_output(
                inputs,
                cost_file_path,
                plot_path,
                asset_owner_index,
                title;
                round_data = true,
                fixed_component = bidding_group_fixed_cost(inputs),
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
    files = get_load_marginal_cost_files(inputs)
    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
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

    # Offer curve
    plot_bid_curve(inputs, plots_path)

    return nothing
end

function plot_bid_curve(inputs::AbstractInputs, plots_path::String)
    # Determine which files should be read
    bidding_group_bid_files = get_bidding_group_bid_file_paths(inputs)
    virtual_reservoir_bid_files = get_virtual_reservoir_bid_file_paths(inputs)
    if !isempty(bidding_group_bid_files)
        plot_no_markup_price = false
        plot_virtual_reservoir_data = false
        bg_quantity_bid_file = bidding_group_bid_files[1]
        bg_price_bid_file = bidding_group_bid_files[2]
        if length(bidding_group_bid_files) == 4
            bg_no_markup_price_bid_file = bidding_group_bid_files[3]
            bg_no_markup_quantity_bid_file = bidding_group_bid_files[4]
            plot_no_markup_price = true
        end
        if !isempty(virtual_reservoir_bid_files)
            plot_virtual_reservoir_data = true
            vr_quantity_bid_file = virtual_reservoir_bid_files[1]
            vr_price_bid_file = virtual_reservoir_bid_files[2]
            if plot_no_markup_price
                if length(virtual_reservoir_bid_files) == 4
                    vr_no_markup_price_bid_file = virtual_reservoir_bid_files[3]
                    vr_no_markup_quantity_bid_file = virtual_reservoir_bid_files[4]
                else
                    plot_no_markup_price = false
                end
            end
        end

        # Read files
        bg_quantity_data, bg_quantity_metadata = read_timeseries_file(bg_quantity_bid_file)
        bg_price_data, bg_price_metadata = read_timeseries_file(bg_price_bid_file)
        if plot_virtual_reservoir_data
            vr_quantity_data, vr_quantity_metadata = read_timeseries_file(vr_quantity_bid_file)
            vr_price_data, vr_price_metadata = read_timeseries_file(vr_price_bid_file)
        end
        if plot_no_markup_price
            bg_no_markup_price_data, bg_no_markup_price_metadata = read_timeseries_file(bg_no_markup_price_bid_file)
            bg_no_markup_quantity_data, bg_no_markup_quantity_metadata =
                read_timeseries_file(bg_no_markup_quantity_bid_file)
            if plot_virtual_reservoir_data
                vr_no_markup_quantity_data, vr_no_markup_quantity_metadata =
                    read_timeseries_file(vr_no_markup_quantity_bid_file)
                vr_no_markup_price_data, vr_no_markup_price_metadata = read_timeseries_file(vr_no_markup_price_bid_file)
            end
        end

        # Validate file metadata
        @assert bg_quantity_metadata.number_of_time_series == bg_price_metadata.number_of_time_series "Mismatch between quantity and price bid file columns"
        @assert bg_quantity_metadata.dimension_size == bg_price_metadata.dimension_size "Mismatch between quantity and price bid file dimensions"
        @assert bg_quantity_metadata.labels == bg_price_metadata.labels "Mismatch between quantity and price bid file labels"
        if plot_no_markup_price
            # Compare the price files
            @assert bg_no_markup_price_metadata.number_of_time_series == bg_price_metadata.number_of_time_series "Mismatch between reference price and price bid file columns"
            # The number of periods in the reference price file is always 1
            # The number of bid segments does not need to match
            @assert bg_no_markup_price_metadata.dimension_size[2:(end-1)] == bg_price_metadata.dimension_size[2:(end-1)] "Mismatch between reference price and price bid file dimensions"
            @assert sort(bg_no_markup_price_metadata.labels) == sort(bg_price_metadata.labels) "Mismatch between reference price and price bid file labels"
            # Compare both "no_markup" files
            @assert bg_no_markup_price_metadata.number_of_time_series ==
                    bg_no_markup_quantity_metadata.number_of_time_series "Mismatch between reference price and reference quantity bid file columns"
            @assert bg_no_markup_price_metadata.dimension_size == bg_no_markup_quantity_metadata.dimension_size "Mismatch between reference price and reference quantity bid file dimensions"
            @assert bg_no_markup_price_metadata.labels == bg_no_markup_quantity_metadata.labels "Mismatch between reference price and reference quantity bid file labels"
        end

        num_labels = bg_quantity_metadata.number_of_time_series
        num_periods, num_scenarios, num_subperiods, num_bid_segments = bg_quantity_metadata.dimension_size

        if plot_no_markup_price
            num_bid_segments_no_markup = bg_no_markup_price_metadata.dimension_size[end]
        end

        # Remove the period dimension
        if num_periods > 1
            # From input files, with all periods
            bg_quantity_data = bg_quantity_data[:, :, :, :, inputs.args.period]
            bg_price_data = bg_price_data[:, :, :, :, inputs.args.period]
        else
            # Or from heuristic bid output files, with a single period
            bg_quantity_data = dropdims(bg_quantity_data; dims = 5)
            bg_price_data = dropdims(bg_price_data; dims = 5)
        end
        if plot_no_markup_price
            bg_no_markup_price_data = dropdims(bg_no_markup_price_data; dims = 5)
            bg_no_markup_quantity_data = dropdims(bg_no_markup_quantity_data; dims = 5)
        end

        # Process virtual reservoir data if available
        num_vr_labels = 0
        if plot_virtual_reservoir_data
            num_vr_labels = vr_quantity_metadata.number_of_time_series
            vr_num_periods, vr_num_scenarios, vr_num_bid_segments = vr_quantity_metadata.dimension_size

            # VR data doesn't have subperiod dimension, so we add it artificially
            # Remove period dimension and add subperiod dimension
            if vr_num_periods > 1
                vr_quantity_data = vr_quantity_data[:, :, :, inputs.args.period]
                vr_price_data = vr_price_data[:, :, :, inputs.args.period]
            else
                vr_quantity_data = dropdims(vr_quantity_data; dims = 4)
                vr_price_data = dropdims(vr_price_data; dims = 4)
            end

            # Add artificial subperiod dimension: [labels, segments, scenarios] -> [labels, segments, subperiods, scenarios]
            # Divide quantity by num_subperiods, repeat price for all subperiods
            vr_quantity_data_with_subperiods =
                Array{Float64, 4}(undef, num_vr_labels, vr_num_bid_segments, num_subperiods, vr_num_scenarios)
            vr_price_data_with_subperiods =
                Array{Float64, 4}(undef, num_vr_labels, vr_num_bid_segments, num_subperiods, vr_num_scenarios)

            for label_idx in 1:num_vr_labels
                for segment in 1:vr_num_bid_segments
                    for scenario in 1:vr_num_scenarios
                        for subperiod in 1:num_subperiods
                            vr_quantity_data_with_subperiods[label_idx, segment, subperiod, scenario] =
                                vr_quantity_data[label_idx, segment, scenario] / num_subperiods
                            vr_price_data_with_subperiods[label_idx, segment, subperiod, scenario] =
                                vr_price_data[label_idx, segment, scenario]
                        end
                    end
                end
            end

            vr_quantity_data = vr_quantity_data_with_subperiods
            vr_price_data = vr_price_data_with_subperiods

            if plot_no_markup_price
                vr_no_markup_num_periods, vr_no_markup_num_scenarios, vr_no_markup_num_bid_segments =
                    vr_no_markup_quantity_metadata.dimension_size

                if vr_no_markup_num_periods > 1
                    vr_no_markup_quantity_data = vr_no_markup_quantity_data[:, :, :, inputs.args.period]
                    vr_no_markup_price_data = vr_no_markup_price_data[:, :, :, inputs.args.period]
                else
                    vr_no_markup_quantity_data = dropdims(vr_no_markup_quantity_data; dims = 4)
                    vr_no_markup_price_data = dropdims(vr_no_markup_price_data; dims = 4)
                end

                # Add artificial subperiod dimension for no_markup VR data
                vr_no_markup_quantity_data_with_subperiods = Array{Float64, 4}(
                    undef,
                    num_vr_labels,
                    vr_no_markup_num_bid_segments,
                    num_subperiods,
                    vr_no_markup_num_scenarios,
                )
                vr_no_markup_price_data_with_subperiods = Array{Float64, 4}(
                    undef,
                    num_vr_labels,
                    vr_no_markup_num_bid_segments,
                    num_subperiods,
                    vr_no_markup_num_scenarios,
                )

                for label_idx in 1:num_vr_labels
                    for segment in 1:vr_no_markup_num_bid_segments
                        for scenario in 1:vr_no_markup_num_scenarios
                            for subperiod in 1:num_subperiods
                                vr_no_markup_quantity_data_with_subperiods[label_idx, segment, subperiod, scenario] =
                                    vr_no_markup_quantity_data[label_idx, segment, scenario] / num_subperiods
                                vr_no_markup_price_data_with_subperiods[label_idx, segment, subperiod, scenario] =
                                    vr_no_markup_price_data[label_idx, segment, scenario]
                            end
                        end
                    end
                end

                vr_no_markup_quantity_data = vr_no_markup_quantity_data_with_subperiods
                vr_no_markup_price_data = vr_no_markup_price_data_with_subperiods
            end
        end

        for subperiod in 1:num_subperiods
            reshaped_quantity = Float64[]
            reshaped_price = Float64[]
            if plot_no_markup_price
                reshaped_no_markup_price = Float64[]
                # the second quantity is necessary because we will sort both vectors in increasing price order
                reshaped_no_markup_quantity = Float64[]
            end

            # Collect bidding group data
            for segment in 1:num_bid_segments
                for label_index in 1:num_labels
                    # mean across scenarios
                    quantity = mean(bg_quantity_data[label_index, segment, subperiod, :])
                    price = mean(bg_price_data[label_index, segment, subperiod, :])
                    # push point
                    push!(reshaped_quantity, quantity)
                    push!(reshaped_price, price)
                end
            end

            # Append virtual reservoir data
            if plot_virtual_reservoir_data
                vr_num_bid_segments = size(vr_quantity_data, 2)
                for segment in 1:vr_num_bid_segments
                    for label_index in 1:num_vr_labels
                        # mean across scenarios
                        quantity = mean(vr_quantity_data[label_index, segment, subperiod, :])
                        price = mean(vr_price_data[label_index, segment, subperiod, :])
                        # push point
                        push!(reshaped_quantity, quantity)
                        push!(reshaped_price, price)
                    end
                end
            end

            if plot_no_markup_price
                # Collect bidding group no_markup data
                for segment in 1:num_bid_segments_no_markup
                    for label_index in 1:num_labels
                        # mean across scenarios
                        no_markup_price = mean(bg_no_markup_price_data[label_index, segment, subperiod, :])
                        no_markup_quantity = mean(bg_no_markup_quantity_data[label_index, segment, subperiod, :])
                        # push point
                        push!(reshaped_no_markup_price, no_markup_price)
                        push!(reshaped_no_markup_quantity, no_markup_quantity)
                    end
                end

                # Append virtual reservoir no_markup data
                if plot_virtual_reservoir_data
                    vr_no_markup_num_bid_segments = size(vr_no_markup_quantity_data, 2)
                    for segment in 1:vr_no_markup_num_bid_segments
                        for label_index in 1:num_vr_labels
                            # mean across scenarios
                            no_markup_price = mean(vr_no_markup_price_data[label_index, segment, subperiod, :])
                            no_markup_quantity = mean(vr_no_markup_quantity_data[label_index, segment, subperiod, :])
                            # push point
                            push!(reshaped_no_markup_price, no_markup_price)
                            push!(reshaped_no_markup_quantity, no_markup_quantity)
                        end
                    end
                end
            end

            sort_order = sortperm(reshaped_price)
            reshaped_quantity = reshaped_quantity[sort_order]
            reshaped_quantity = cumsum(reshaped_quantity)
            reshaped_price = reshaped_price[sort_order]
            if plot_no_markup_price
                no_markup_sort_order = sortperm(reshaped_no_markup_price)
                reshaped_no_markup_quantity = reshaped_no_markup_quantity[no_markup_sort_order]
                reshaped_no_markup_quantity = cumsum(reshaped_no_markup_quantity)
                reshaped_no_markup_price = reshaped_no_markup_price[no_markup_sort_order]
            end

            quantity_data_to_plot = Float64[0.0]
            price_data_to_plot = Float64[0.0]

            for (quantity, price) in zip(reshaped_quantity, reshaped_price)
                # old point
                push!(quantity_data_to_plot, quantity_data_to_plot[end])
                push!(price_data_to_plot, price)
                # new point
                push!(quantity_data_to_plot, quantity)
                push!(price_data_to_plot, price)
            end

            if plot_no_markup_price
                no_markup_quantity_data_to_plot = Float64[0.0]
                no_markup_price_data_to_plot = Float64[0.0]

                for (quantity, price) in zip(reshaped_no_markup_quantity, reshaped_no_markup_price)
                    # old point
                    push!(no_markup_quantity_data_to_plot, no_markup_quantity_data_to_plot[end])
                    push!(no_markup_price_data_to_plot, price)
                    # new point
                    push!(no_markup_quantity_data_to_plot, quantity)
                    push!(no_markup_price_data_to_plot, price)
                end
            end

            configs = Vector{Config}()

            title = get_name(inputs, "available_bids")
            if num_subperiods > 1
                title *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end
            color_idx = 0
            color_idx += 1
            name = get_name(inputs, "bids")
            push!(
                configs,
                Config(;
                    x = quantity_data_to_plot,
                    y = price_data_to_plot,
                    name = name,
                    line = Dict("color" => _get_plot_color(color_idx)),
                    type = "line",
                ),
            )
            if plot_no_markup_price
                color_idx += 1
                name = get_name(inputs, "operating_cost")
                push!(
                    configs,
                    Config(;
                        x = no_markup_quantity_data_to_plot,
                        y = no_markup_price_data_to_plot,
                        name = name,
                        line = Dict("color" => _get_plot_color(color_idx)),
                        type = "line",
                    ),
                )
            end

            # Add demand lines
            ex_ante_demand, ex_post_demand = get_demands_to_plot(inputs)
            demand_name = "demand"
            # Remove all renewable generation from the demand
            if any_elements(inputs, RenewableUnit)
                ex_ante_generation, ex_post_generation = get_renewable_generation_to_plot(inputs)
                ex_ante_demand = ex_ante_demand .- ex_ante_generation
                ex_post_demand = ex_post_demand .- ex_post_generation
                demand_name = "net_demand"
            end
            # Add back the ex-ante value of renewable bids
            if any_elements(inputs, RenewableUnit; filters = [!has_no_bidding_group])
                ex_ante_generation, _ = get_renewable_generation_to_plot(inputs; filters = [!has_no_bidding_group])
                ex_ante_demand = ex_ante_demand .+ ex_ante_generation
                num_subscenarios = size(ex_post_demand, 1)
                for s in 1:num_subscenarios
                    ex_post_demand[s, :] = ex_post_demand[s, :] .+ ex_ante_generation
                end
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
                title = Dict(
                    "text" => title,
                    "font" => Dict("size" => title_font_size()),
                ),
                xaxis = Dict(
                    "title" => Dict(
                        "text" => "$(get_name(inputs, "quantity")) [MW]",
                        "font" => Dict("size" => axis_title_font_size()),
                    ),
                    "tickfont" => Dict("size" => axis_tick_font_size()),
                ),
                yaxis = Dict(
                    "title" => Dict(
                        "text" => "$(get_name(inputs, "price")) [\$/MWh]",
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

            _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "bid_curve_subperiod_$subperiod.html"))
        end
    end

    return nothing
end

function plot_agent_output(
    inputs::AbstractInputs,
    bg_file_path::String,
    plot_path::String,
    asset_owner_index::Int,
    title::String;
    round_data::Bool = false,
    ex_ante_plot::Bool = false,
    fixed_component::Vector{Float64} = Float64[],
    vr_file_path::String = "",
)
    # Read and format BG data
    bg_data, bg_metadata, num_subperiods, num_subscenarios = format_data_to_plot(
        inputs,
        bg_file_path;
        asset_owner_index,
    )
    if round_data
        bg_data = round.(bg_data; digits = 1)
    end

    # Read and format VR data
    if !isempty(vr_file_path)
        @assert isempty(fixed_component) "Fixed component plotting not supported for virtual reservoir data"
        vr_data, vr_metadata, _, _ = format_data_to_plot(
            inputs,
            vr_file_path;
            asset_owner_index,
        )
        if round_data
            vr_data = round.(vr_data; digits = 1)
        end
    end

    # Read and format fixed component data
    if !isempty(fixed_component)
        asset_owner_bidding_groups = Int[]
        bidding_group_indexes =
            index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
        for bg in bidding_group_indexes
            if bidding_group_asset_owner_index(inputs, bg) == asset_owner_index
                push!(asset_owner_bidding_groups, bg)
            end
        end
        fixed_component = sum(fixed_component[asset_owner_bidding_groups]; dims = 1) / num_subperiods
    end

    configs = Vector{Config}()
    for subperiod in 1:num_subperiods
        variable_component_name = ""
        if !isempty(fixed_component)
            fixed_component_name = get_name(inputs, "fixed_cost")
            variable_component_name = get_name(inputs, "variable_cost")
            if num_subperiods > 1
                fixed_component_name *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end
            push!(
                configs,
                Config(;
                    x = 1:num_subscenarios,
                    y = repeat(fixed_component, num_subscenarios),
                    name = fixed_component_name,
                    marker = Dict("color" => _get_plot_color(num_subperiods + subperiod)),
                    type = "bar",
                ),
            )
        end
        if !isempty(vr_file_path)
            variable_component_name = title * " - Grupo Ofertante"
            vr_component_name = title * " - Reservatório Virtual"
            if num_subperiods > 1
                vr_component_name *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end
            push!(
                configs,
                Config(;
                    x = 1:num_subscenarios,
                    y = vr_data[1, :] ./ num_subperiods, # VR data has no subperiod dimension
                    name = vr_component_name,
                    marker = Dict("color" => _get_plot_color(subperiod; dark_shade = true)),
                    type = "bar",
                ),
            )
        end
        if num_subperiods > 1
            variable_component_name *= " - $(get_name(inputs, "subperiod")) $subperiod"
        end
        push!(
            configs,
            Config(;
                x = 1:num_subscenarios,
                y = bg_data[subperiod, :],
                name = variable_component_name,
                marker = Dict("color" => _get_plot_color(subperiod)),
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
        barmode = "stack",
        title = Dict(
            "text" => title,
            "font" => Dict("size" => title_font_size()),
        ),
        xaxis = Dict(
            "title" => Dict(
                "text" => x_axis_title,
                "font" => Dict("size" => axis_title_font_size()),
            ),
            "tickmode" => "array",
            "tickvals" => x_axis_tickvals,
            "ticktext" => x_axis_ticktext,
            "tickfont" => Dict("size" => axis_tick_font_size()),
        ),
        yaxis = Dict(
            "title" => Dict(
                "text" => "$(bg_metadata.unit)",
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

    _save_plot(Plot(configs, main_configuration), plot_path)

    return nothing
end

function plot_operator_output(
    inputs::AbstractInputs,
    bg_file_path::String,
    plot_path::String,
    title::String;
    round_data::Bool = false,
    ex_ante_plot::Bool = false,
    vr_file_path::String = "",
)
    bg_data, bg_metadata, num_subperiods, num_subscenarios = format_data_to_plot(
        inputs,
        bg_file_path;
    )
    if round_data
        bg_data = round.(bg_data; digits = 1)
    end

    # Read and format VR data
    if !isempty(vr_file_path)
        vr_data, vr_metadata, _, _ = format_data_to_plot(
            inputs,
            vr_file_path;
        )
        if round_data
            vr_data = round.(vr_data; digits = 1)
        end
    end

    asset_owner_indexes = index_of_elements(inputs, AssetOwner)

    for subperiod in 1:num_subperiods
        configs = Vector{Config}()
        for asset_owner_index in asset_owner_indexes
            ao_label_for_bg = asset_owner_label(inputs, asset_owner_index)
            if !isempty(vr_file_path)
                ao_label_for_vr = ao_label_for_bg * " - Reservatório Virtual"
                ao_label_for_bg *= " - Grupo Ofertante"
            end
            push!(
                configs,
                Config(;
                    x = 1:num_subscenarios,
                    y = bg_data[asset_owner_index, subperiod, :],
                    name = ao_label_for_bg,
                    marker = Dict("color" => _get_plot_color(asset_owner_index)),
                    type = "bar",
                ),
            )
            if !isempty(vr_file_path)
                push!(
                    configs,
                    Config(;
                        x = 1:num_subscenarios,
                        y = vr_data[asset_owner_index, 1, :] ./ num_subperiods, # VR data has no subperiod dimension
                        name = ao_label_for_vr,
                        marker = Dict("color" => _get_plot_color(asset_owner_index; dark_shade = true)),
                        type = "bar",
                    ),
                )
            end
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
            title = Dict(
                "text" => plot_title,
                "font" => Dict("size" => title_font_size()),
            ),
            xaxis = Dict(
                "title" => Dict(
                    "text" => x_axis_title,
                    "font" => Dict("size" => axis_title_font_size()),
                ),
                "tickmode" => "array",
                "tickvals" => x_axis_tickvals,
                "ticktext" => x_axis_ticktext,
                "tickfont" => Dict("size" => axis_tick_font_size()),
            ),
            yaxis = Dict(
                "title" => Dict(
                    "text" => "$(bg_metadata.unit)",
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

        _save_plot(Plot(configs, main_configuration), plot_path * "_subperiod_$subperiod.html")
    end

    return nothing
end

function plot_general_output(
    inputs::AbstractInputs;
    file_path::String,
    plot_path::String,
    title::String,
    stack::Bool = false,
    round_data::Bool = false,
    ex_ante_plot::Bool = false,
    vr_file_path::String = "",
)
    data, metadata, num_subperiods, num_subscenarios = format_data_to_plot(
        inputs,
        file_path;
        aggregate_header_by_asset_owner = false,
    )
    if round_data
        data = round.(data; digits = 1)
    end
    number_of_agents = size(data, 1)

    plot_kwargs = if stack
        Dict(
            :mode => "lines+markers",
            :stackgroup => "one",
        )
    else
        Dict()
    end

    color_idx = 0
    configs = Vector{Config}()
    for agent in 1:number_of_agents, subperiod in 1:num_subperiods
        label = metadata.labels[agent]
        if num_subperiods > 1
            label *= " - $(get_name(inputs, "subperiod")) $subperiod"
        end
        color_idx += 1
        push!(
            configs,
            Config(;
                x = 1:num_subscenarios,
                y = data[agent, subperiod, :],
                name = label,
                marker = Dict("color" => _get_plot_color(color_idx)),
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
        title = Dict(
            "text" => title,
            "font" => Dict("size" => title_font_size()),
        ),
        xaxis = Dict(
            "title" => Dict(
                "text" => x_axis_title,
                "font" => Dict("size" => axis_title_font_size()),
            ),
            "tickmode" => "array",
            "tickvals" => x_axis_tickvals,
            "ticktext" => x_axis_ticktext,
            "tickfont" => Dict("size" => axis_tick_font_size()),
        ),
        yaxis = Dict(
            "title" => Dict(
                "text" => "$(metadata.unit)",
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

    _save_plot(Plot(configs, main_configuration), plot_path * ".html")

    return nothing
end
