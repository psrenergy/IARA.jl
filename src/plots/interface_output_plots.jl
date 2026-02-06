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
            plot_path,
            get_name(inputs, "ex_ante_revenue");
            bg_file_path = revenue_files[1],
            vr_file_path = vr_revenue_files[1],
            round_data = true,
            ex_ante_plot = true,
        )
        plot_path = joinpath(plots_path, "total_revenue_ex_post")
        plot_operator_output(
            inputs,
            plot_path,
            get_name(inputs, "ex_post_revenue");
            bg_file_path = revenue_files[2],
            vr_file_path = vr_revenue_files[2],
            round_data = true,
        )
    else
        @assert length(revenue_files) == 1
        plot_path = joinpath(plots_path, "total_revenue")
        plot_operator_output(
            inputs,
            plot_path,
            get_name(inputs, "total_revenue");
            bg_file_path = revenue_files[1],
            vr_file_path = vr_revenue_files[1],
            round_data = true,
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
            plot_path,
            get_name(inputs, "ex_ante_generation");
            bg_file_path = generation_files[1],
            vr_file_path = vr_generation_files[1],
            ex_ante_plot = true,
        )
        plot_path = joinpath(plots_path, "total_generation_ex_post")
        plot_operator_output(
            inputs,
            plot_path,
            get_name(inputs, "ex_post_generation");
            bg_file_path = generation_files[2],
            vr_file_path = vr_generation_files[2],
        )
    else
        @assert length(generation_files) == 1
        plot_path = joinpath(plots_path, "total_generation")
        plot_operator_output(
            inputs,
            plot_path,
            get_name(inputs, "total_generation");
            bg_file_path = generation_files[1],
            vr_file_path = vr_generation_files[1],
        )
    end

    # VR final energy account
    energy_account_file = get_virtual_reservoir_final_energy_account_file(inputs)
    if plot_virtual_reservoir_results
        plot_path = joinpath(plots_path, "vr_final_energy_account")
        plot_operator_output(
            inputs,
            plot_path,
            get_name(inputs, "final_energy_account");
            vr_file_path = energy_account_file,
            ex_ante_plot = true,
            subscenario_index = 1,
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
                plot_path,
                asset_owner_index,
                title;
                bg_file_path = profit_file_path,
                vr_file_path = vr_profit_file_path,
                round_data = true,
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
                plot_path,
                asset_owner_index,
                title;
                bg_file_path = revenue_files[1],
                vr_file_path = vr_revenue_files[1],
                round_data = true,
                ex_ante_plot = true,
            )
        end
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "ex_post_revenue"))"
            plot_path = joinpath(plots_path, "revenue_ex_post_$ao_label.html")
            plot_agent_output(
                inputs,
                plot_path,
                asset_owner_index,
                title;
                bg_file_path = revenue_files[2],
                vr_file_path = vr_revenue_files[2],
                round_data = true,
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
                plot_path,
                asset_owner_index,
                title;
                bg_file_path = revenue_files[1],
                vr_file_path = vr_revenue_files[1],
                round_data = true,
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
                plot_path,
                asset_owner_index,
                title;
                bg_file_path = generation_files[1],
                vr_file_path = vr_generation_files[1],
                ex_ante_plot = true,
            )
        end
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "ex_post_generation"))"
            plot_path = joinpath(plots_path, "generation_ex_post_$ao_label.html")
            plot_agent_output(
                inputs,
                plot_path,
                asset_owner_index,
                title;
                bg_file_path = generation_files[2],
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
                plot_path,
                asset_owner_index,
                title;
                bg_file_path = generation_files[1],
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
                plot_path,
                asset_owner_index,
                title;
                bg_file_path = cost_file_path,
                round_data = true,
                fixed_component = bidding_group_fixed_cost(inputs),
            )
        end
    end

    # VR final energy account
    energy_account_file = get_virtual_reservoir_final_energy_account_file(inputs)
    if plot_virtual_reservoir_results
        for asset_owner_index in index_of_elements(inputs, AssetOwner)
            ao_label = asset_owner_label(inputs, asset_owner_index)
            title = "$ao_label - $(get_name(inputs, "final_energy_account"))"
            plot_path = joinpath(plots_path, "vr_final_energy_account_$ao_label.html")
            plot_agent_output(
                inputs,
                plot_path,
                asset_owner_index,
                title;
                vr_file_path = energy_account_file,
                ex_ante_plot = true,
                subscenario_index = 1,
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

            # Separate sell (positive) and purchase (negative) bids
            sell_indices = findall(q -> q >= 0, reshaped_quantity)
            purchase_indices = findall(q -> q < 0, reshaped_quantity)
            has_purchase_bids = !isempty(purchase_indices)

            # Process sell bids
            sell_quantity = reshaped_quantity[sell_indices]
            sell_price = reshaped_price[sell_indices]

            sort_order = sortperm(sell_price)
            sell_quantity = sell_quantity[sort_order]
            sell_quantity = cumsum(sell_quantity)
            sell_price = sell_price[sort_order]

            # Process purchase bids (if any)
            purchase_quantity = Float64[]
            purchase_price = Float64[]
            if has_purchase_bids
                purchase_quantity = reshaped_quantity[purchase_indices]
                purchase_price = reshaped_price[purchase_indices]

                purchase_sort_order = sortperm(purchase_price)
                purchase_quantity = purchase_quantity[purchase_sort_order]
                purchase_quantity = cumsum(purchase_quantity)
                purchase_price = purchase_price[purchase_sort_order]
            end

            # Process no_markup data
            if plot_no_markup_price
                no_markup_sort_order = sortperm(reshaped_no_markup_price)
                reshaped_no_markup_quantity = reshaped_no_markup_quantity[no_markup_sort_order]
                reshaped_no_markup_quantity = cumsum(reshaped_no_markup_quantity)
                reshaped_no_markup_price = reshaped_no_markup_price[no_markup_sort_order]
            end

            # Build sell bid plot data
            sell_quantity_data_to_plot = Float64[0.0]
            sell_price_data_to_plot = Float64[0.0]
            for (quantity, price) in zip(sell_quantity, sell_price)
                # old point
                push!(sell_quantity_data_to_plot, sell_quantity_data_to_plot[end])
                push!(sell_price_data_to_plot, price)
                # new point
                push!(sell_quantity_data_to_plot, quantity)
                push!(sell_price_data_to_plot, price)
            end

            # Build purchase bid plot data (if any)
            purchase_quantity_data_to_plot = Float64[0.0]
            purchase_price_data_to_plot = Float64[0.0]
            if has_purchase_bids
                for (quantity, price) in zip(purchase_quantity, purchase_price)
                    # old point
                    push!(purchase_quantity_data_to_plot, purchase_quantity_data_to_plot[end])
                    push!(purchase_price_data_to_plot, price)
                    # new point (invert quantity to make it positive for display)
                    push!(purchase_quantity_data_to_plot, -quantity)
                    push!(purchase_price_data_to_plot, price)
                end
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
            name = has_purchase_bids ? get_name(inputs, "sell_bids") : get_name(inputs, "bids")
            push!(
                configs,
                Config(;
                    x = sell_quantity_data_to_plot,
                    y = sell_price_data_to_plot,
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
            if has_purchase_bids
                color_idx += 1
                name = get_name(inputs, "purchase_bids")
                push!(
                    configs,
                    Config(;
                        x = purchase_quantity_data_to_plot,
                        y = purchase_price_data_to_plot,
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
            # Calculate y-axis limits including sell, purchase, and no_markup prices
            all_prices = vcat(sell_price_data_to_plot, purchase_price_data_to_plot)
            if plot_no_markup_price
                all_prices = vcat(all_prices, no_markup_price_data_to_plot)
            end
            y_axis_limits = [minimum(minimum.(all_prices)), maximum(maximum.(all_prices))] .* 1.1
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
            # First subscenario demand
            if plot_virtual_reservoir_data
                subscenario_idx = 1
                color_idx += 1
                push!(
                    configs,
                    Config(;
                        x = range(
                            ex_post_demand[subscenario_idx, demand_time_index],
                            ex_post_demand[subscenario_idx, demand_time_index];
                            length = 100,
                        ),
                        y = y_axis_range,
                        name = get_name(inputs, "first_scenario_$demand_name"),
                        line = Dict("color" => _get_plot_color(color_idx), "dash" => "dash"),
                        type = "line",
                        mode = "lines",
                        hovertemplate = "%{x} MWh",
                    ),
                )
            end

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
    plot_path::String,
    asset_owner_index::Int,
    title::String;
    bg_file_path::String = "",
    vr_file_path::String = "",
    round_data::Bool = false,
    ex_ante_plot::Bool = false,
    fixed_component::Vector{Float64} = Float64[],
    subscenario_index::Union{Int, Nothing} = nothing,
)
    if isempty(bg_file_path) && isempty(vr_file_path)
        error("At least one of bg_file_path or vr_file_path must be provided")
    end

    # Read and format BG data
    if !isempty(bg_file_path)
        bg_data, bg_metadata, bg_num_subperiods, bg_num_subscenarios = format_data_to_plot(
            inputs,
            bg_file_path;
            asset_owner_index,
            subscenario_index,
        )
        if round_data
            bg_data = round.(bg_data; digits = 1)
        end
    end

    # Read and format VR data
    if !isempty(vr_file_path)
        @assert isempty(fixed_component) "Fixed component plotting not supported for virtual reservoir data"
        vr_data, vr_metadata, vr_num_subperiods, vr_num_subscenarios = format_data_to_plot(
            inputs,
            vr_file_path;
            asset_owner_index,
            subscenario_index,
        )
        if round_data
            vr_data = round.(vr_data; digits = 1)
        end
    end

    if !isempty(bg_file_path)
        num_subperiods = bg_num_subperiods
        num_subscenarios = bg_num_subscenarios
    else
        num_subperiods = vr_num_subperiods
        num_subscenarios = vr_num_subscenarios
    end

    unit = if !isempty(bg_file_path)
        bg_metadata.unit
    else
        vr_metadata.unit
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

        # Calculate VR values once for this subperiod (used by both BG and VR)
        vr_y_positive = Float64[]
        if !isempty(vr_file_path)
            vr_y_values = vr_data[1, :] ./ num_subperiods
            vr_y_positive = max.(vr_y_values, 0.0)
        end

        if !isempty(bg_file_path)
            if !isempty(vr_file_path)
                variable_component_name = title * " - Grupo Ofertante"
            end
            if num_subperiods > 1
                variable_component_name *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end

            # Stack BG on top of positive VR
            bg_y_values = bg_data[subperiod, :]
            bg_base = isempty(vr_file_path) ? zeros(Float64, num_subscenarios) : vr_y_positive

            push!(
                configs,
                Config(;
                    x = 1:num_subscenarios,
                    y = bg_y_values,
                    base = bg_base,
                    name = variable_component_name,
                    marker = Dict("color" => _get_plot_color(subperiod)),
                    type = "bar",
                    customdata = bg_y_values,
                    hovertemplate = "(%{customdata})",
                ),
            )
        end
        if !isempty(vr_file_path)
            vr_component_name = title
            if !isempty(bg_file_path)
                vr_component_name *= " - Reservatório Virtual"
            end
            if num_subperiods > 1
                vr_component_name *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end

            # vr_y_positive already calculated above; now calculate negative
            vr_y_values = vr_data[1, :] ./ num_subperiods
            vr_y_negative = min.(vr_y_values, 0.0)

            has_positive_vr = any(vr_y_positive .> 0)
            has_negative_vr = any(vr_y_negative .< 0)

            # Add positive VR bars
            if has_positive_vr
                push!(
                    configs,
                    Config(;
                        x = 1:num_subscenarios,
                        y = vr_y_positive,
                        name = vr_component_name,
                        marker = Dict("color" => _get_plot_color(subperiod; dark_shade = true)),
                        type = "bar",
                        legendgroup = "vr_$subperiod",
                        hovertemplate = "(%{y})",
                    ),
                )
            end

            # Add negative VR bars (always start from zero, going down)
            if has_negative_vr
                push!(
                    configs,
                    Config(;
                        x = 1:num_subscenarios,
                        y = vr_y_negative,
                        base = zeros(Float64, num_subscenarios),
                        name = vr_component_name,
                        marker = Dict("color" => _get_plot_color(subperiod; dark_shade = true)),
                        type = "bar",
                        legendgroup = "vr_$subperiod",
                        showlegend = !has_positive_vr,
                        hovertemplate = "(%{y})",
                    ),
                )
            end
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
    main_configuration = Config(;
        barmode = "overlay",
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
                "text" => "$unit",
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
    plot_path::String,
    title::String;
    bg_file_path::String = "",
    vr_file_path::String = "",
    round_data::Bool = false,
    ex_ante_plot::Bool = false,
    subscenario_index::Union{Int, Nothing} = nothing,
)
    if isempty(bg_file_path) && isempty(vr_file_path)
        error("At least one of bg_file_path or vr_file_path must be provided")
    end

    if !isempty(bg_file_path)
        bg_data, bg_metadata, bg_num_subperiods, bg_num_subscenarios = format_data_to_plot(
            inputs,
            bg_file_path;
            subscenario_index,
        )
        if round_data
            bg_data = round.(bg_data; digits = 1)
        end
    end

    # Read and format VR data
    if !isempty(vr_file_path)
        vr_data, vr_metadata, vr_num_subperiods, vr_num_subscenarios = format_data_to_plot(
            inputs,
            vr_file_path;
            subscenario_index,
        )
        if round_data
            vr_data = round.(vr_data; digits = 1)
        end
    end

    if !isempty(bg_file_path)
        num_subperiods = bg_num_subperiods
        num_subscenarios = bg_num_subscenarios
    else
        num_subperiods = vr_num_subperiods
        num_subscenarios = vr_num_subscenarios
    end

    unit = if !isempty(bg_file_path)
        bg_metadata.unit
    else
        vr_metadata.unit
    end

    asset_owner_indexes = index_of_elements(inputs, AssetOwner)

    for subperiod in 1:num_subperiods
        # First pass: collect all positive VR cumulative sums per x position for stacking BG on top
        positive_vr_cumsum = Dict{Int, Vector{Float64}}()

        for asset_owner_index in asset_owner_indexes
            x_positions = asset_owner_index:(length(asset_owner_indexes)+1):num_subscenarios*(length(asset_owner_indexes,)+1)

            if !isempty(vr_file_path)
                vr_y_values = vcat(vr_data[asset_owner_index, 1, :] ./ num_subperiods, 0.0)
                # For diverging stacked bars: separate positive and negative
                vr_y_positive = max.(vr_y_values, 0.0)

                # Track positive VR for stacking BG on top
                for (idx, x_pos) in enumerate(x_positions)
                    if !haskey(positive_vr_cumsum, x_pos)
                        positive_vr_cumsum[x_pos] = zeros(Float64, length(x_positions))
                    end
                    positive_vr_cumsum[x_pos][idx] = vr_y_positive[idx]
                end
            end
        end

        # Second pass: build configs in correct order (BG first, then VR)
        configs = Vector{Config}()
        for asset_owner_index in asset_owner_indexes
            ao_label = asset_owner_label(inputs, asset_owner_index)
            x_positions = asset_owner_index:(length(asset_owner_indexes)+1):num_subscenarios*(length(asset_owner_indexes,)+1)

            if !isempty(bg_file_path)
                ao_label_for_bg = ao_label
                if !isempty(vr_file_path)
                    ao_label_for_bg *= " - Grupo Ofertante"
                end
                bg_y_values = vcat(bg_data[asset_owner_index, subperiod, :], 0.0)

                # Stack BG on top of positive VR
                bg_base = zeros(Float64, length(bg_y_values))
                if !isempty(vr_file_path)
                    for (idx, x_pos) in enumerate(x_positions)
                        if haskey(positive_vr_cumsum, x_pos)
                            bg_base[idx] = positive_vr_cumsum[x_pos][idx]
                        end
                    end
                end

                push!(
                    configs,
                    Config(;
                        x = x_positions,
                        y = bg_y_values,
                        base = bg_base,
                        name = ao_label_for_bg,
                        marker = Dict("color" => _get_plot_color(asset_owner_index)),
                        type = "bar",
                        customdata = bg_y_values,
                        hovertemplate = "(%{customdata})",
                    ),
                )
            end

            if !isempty(vr_file_path)
                ao_label_for_vr = ao_label
                if !isempty(bg_file_path)
                    ao_label_for_vr *= " - Reservatório Virtual"
                end
                vr_y_values = vcat(vr_data[asset_owner_index, 1, :] ./ num_subperiods, 0.0)
                # For diverging stacked bars: separate positive and negative
                vr_y_positive = max.(vr_y_values, 0.0)
                vr_y_negative = min.(vr_y_values, 0.0)

                has_positive_vr = any(vr_y_positive .> 0)
                has_negative_vr = any(vr_y_negative .< 0)

                # Add positive VR bars
                if has_positive_vr
                    push!(
                        configs,
                        Config(;
                            x = x_positions,
                            y = vr_y_positive,
                            name = ao_label_for_vr,
                            marker = Dict("color" => _get_plot_color(asset_owner_index; dark_shade = true)),
                            type = "bar",
                            hovertemplate = "(%{y})",
                            legendgroup = "vr_$asset_owner_index",
                        ),
                    )
                end

                # Add negative VR bars (always start from zero, going down)
                if has_negative_vr
                    push!(
                        configs,
                        Config(;
                            x = x_positions,
                            y = vr_y_negative,
                            base = zeros(Float64, length(vr_y_negative)),
                            name = ao_label_for_vr,
                            marker = Dict("color" => _get_plot_color(asset_owner_index; dark_shade = true)),
                            type = "bar",
                            hovertemplate = "(%{y})",
                            legendgroup = "vr_$asset_owner_index",
                            showlegend = !has_positive_vr,
                        ),
                    )
                end
            end
        end

        if ex_ante_plot
            x_axis_title = ""
            x_axis_tickvals = []
            x_axis_ticktext = []
        else
            # This is actually the subscenario, with a simplified name for UI cases
            x_axis_title = get_name(inputs, "scenario")
            x_axis_tickvals = 1:num_subscenarios*(length(asset_owner_indexes)+1)
            ref_ao_for_ticktext = Int(round((length(asset_owner_indexes) + 1) / 2))
            x_axis_ticktext = String[]
            for tick in 1:num_subscenarios*(length(asset_owner_indexes)+1)
                if mod(tick - ref_ao_for_ticktext, length(asset_owner_indexes) + 1) == 0
                    push!(x_axis_ticktext, string(div(tick - ref_ao_for_ticktext, length(asset_owner_indexes) + 1) + 1))
                else
                    push!(x_axis_ticktext, "")
                end
            end
        end
        plot_title = title
        if num_subperiods > 1
            plot_title *= " - $(get_name(inputs, "subperiod")) $subperiod"
        end
        main_configuration = Config(;
            barmode = "overlay",
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
                    "text" => "$unit",
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
