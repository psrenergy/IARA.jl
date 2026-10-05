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
            plot_cut_elastic_demand = true,
            plot_attended_elastic_demand = false,
        )
        plot_path = joinpath(plots_path, "total_revenue_ex_post")
        plot_operator_output(
            inputs,
            plot_path,
            get_name(inputs, "ex_post_revenue");
            bg_file_path = revenue_files[2],
            vr_file_path = vr_revenue_files[2],
            round_data = true,
            plot_cut_elastic_demand = true,
            plot_attended_elastic_demand = false,
        )
        # Ex-ante revenue summed to every ex-post scenario, without splitting the bars by source
        vr_total_revenue_file = if plot_virtual_reservoir_results
            get_virtual_reservoir_two_settlement_total_revenue_file(inputs)
        else
            ""
        end
        plot_path = joinpath(plots_path, "total_revenue")
        plot_operator_output(
            inputs,
            plot_path,
            get_name(inputs, "total_revenue");
            bg_file_path = get_two_settlement_total_revenue_file(inputs),
            vr_file_path = vr_total_revenue_file,
            round_data = true,
            merge_bg_and_vr = true,
            plot_cut_elastic_demand = true,
            plot_attended_elastic_demand = false,
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
            plot_cut_elastic_demand = true,
            plot_attended_elastic_demand = false,
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
            plot_cut_elastic_demand = true,
        )
        plot_path = joinpath(plots_path, "total_generation_ex_post")
        plot_operator_output(
            inputs,
            plot_path,
            get_name(inputs, "ex_post_generation");
            bg_file_path = generation_files[2],
            vr_file_path = vr_generation_files[2],
            plot_cut_elastic_demand = true,
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
            plot_cut_elastic_demand = true,
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
                cut_elastic_demand = get_cut_elastic_demand_to_plot(inputs, profit_file_path; asset_owner_index),
                plot_attended_elastic_demand = false,
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
                cut_elastic_demand = get_cut_elastic_demand_to_plot(inputs, revenue_files[1]; asset_owner_index),
                plot_attended_elastic_demand = false,
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
                cut_elastic_demand = get_cut_elastic_demand_to_plot(inputs, revenue_files[2]; asset_owner_index),
                plot_attended_elastic_demand = false,
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
                cut_elastic_demand = get_cut_elastic_demand_to_plot(inputs, revenue_files[1]; asset_owner_index),
                plot_attended_elastic_demand = false,
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
                cut_elastic_demand = get_cut_elastic_demand_to_plot(inputs, generation_files[1]; asset_owner_index),
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
                cut_elastic_demand = get_cut_elastic_demand_to_plot(inputs, generation_files[2]; asset_owner_index),
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
                cut_elastic_demand = get_cut_elastic_demand_to_plot(inputs, generation_files[1]; asset_owner_index),
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
                cut_elastic_demand = get_cut_elastic_demand_to_plot(inputs, cost_file_path; asset_owner_index),
                plot_attended_elastic_demand = false,
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

        num_periods, num_scenarios, num_subperiods, num_bid_segments = bg_quantity_metadata.dimension_size

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

        # When some demand unit bids through a bidding group, the negative bidding group quantities are demand offers.
        # In this case two plots are built per subperiod: one with the demand offers as demand cut offers against the
        # total demand, and one with the demand offers as steps of the demand curve, starting from the inelastic demand.
        has_demand_offers = any_elements(inputs, DemandUnit; filters = [!has_no_bidding_group])
        ex_ante_demand, ex_post_demand, demand_name = _get_bid_curve_demands(inputs)
        if has_demand_offers
            ex_ante_inelastic_demand, ex_post_inelastic_demand, _ =
                _get_bid_curve_demands(inputs; filters = [has_no_bidding_group])
            # Bids of each subscenario of the ex-post clearing, adjusted by each bidding group's ex-post adjustment mode
            bg_ex_post_quantity_data =
                _read_ex_post_quantity_bids(inputs, bg_quantity_metadata.labels, num_bid_segments)
        end

        for subperiod in 1:num_subperiods
            # Bidding group and virtual reservoir offers are kept apart, since negative quantities are demand offers
            # in the former and purchase offers in the latter
            bg_quantity, bg_price = _mean_offers_in_subperiod(bg_quantity_data, bg_price_data, subperiod)
            vr_quantity, vr_price = Float64[], Float64[]
            if plot_virtual_reservoir_data
                vr_quantity, vr_price = _mean_offers_in_subperiod(vr_quantity_data, vr_price_data, subperiod)
            end
            if plot_no_markup_price
                bg_no_markup_quantity, bg_no_markup_price =
                    _mean_offers_in_subperiod(bg_no_markup_quantity_data, bg_no_markup_price_data, subperiod)
                vr_no_markup_quantity, vr_no_markup_price = Float64[], Float64[]
                if plot_virtual_reservoir_data
                    vr_no_markup_quantity, vr_no_markup_price =
                        _mean_offers_in_subperiod(vr_no_markup_quantity_data, vr_no_markup_price_data, subperiod)
                end
            end

            # Demand offers of the ex-ante clearing, with positive quantities
            demand_offer_quantity, demand_offer_price =
                has_demand_offers ? _demand_offers(bg_quantity, bg_price) : (Float64[], Float64[])

            # Calculate y-axis limits including every offer price, so that the plots of the subperiod share them
            all_prices = vcat(0.0, bg_price, vr_price)
            if plot_no_markup_price
                all_prices = vcat(all_prices, bg_no_markup_price, vr_no_markup_price)
            end
            y_axis_limits = [minimum(all_prices), maximum(all_prices)] .* 1.1
            y_axis_range = range(y_axis_limits[1], y_axis_limits[2]; length = 100)

            demand_time_index = (inputs.args.period - 1) * num_subperiods + subperiod

            for demand_as_curve in (has_demand_offers ? [false, true] : [false])
                offers = _split_sell_and_purchase_offers(
                    bg_quantity,
                    bg_price,
                    vr_quantity,
                    vr_price;
                    has_demand_offers,
                    demand_as_curve,
                )
                has_purchase_bids = !isempty(offers.purchase_quantity)
                sell_quantity_data_to_plot, sell_price_data_to_plot =
                    _offer_curve_points(offers.sell_quantity, offers.sell_price)
                purchase_quantity_data_to_plot, purchase_price_data_to_plot =
                    _offer_curve_points(offers.purchase_quantity, offers.purchase_price)

                has_no_markup_purchase_bids = false
                if plot_no_markup_price
                    no_markup_offers = _split_sell_and_purchase_offers(
                        bg_no_markup_quantity,
                        bg_no_markup_price,
                        vr_no_markup_quantity,
                        vr_no_markup_price;
                        has_demand_offers,
                        demand_as_curve,
                    )
                    has_no_markup_purchase_bids = !isempty(no_markup_offers.purchase_quantity)
                    no_markup_quantity_data_to_plot, no_markup_price_data_to_plot =
                        _offer_curve_points(no_markup_offers.sell_quantity, no_markup_offers.sell_price)
                    no_markup_purchase_quantity_data_to_plot, no_markup_purchase_price_data_to_plot =
                        _offer_curve_points(no_markup_offers.purchase_quantity, no_markup_offers.purchase_price)
                end

                configs = Vector{Config}()

                title = get_name(inputs, "available_bids")
                if has_demand_offers
                    title *= " - $(get_name(inputs, demand_as_curve ? "demand_curve" : "demand_cut_offers"))"
                end
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
                if has_no_markup_purchase_bids
                    color_idx += 1
                    name = get_name(inputs, "willingness_to_pay")
                    push!(
                        configs,
                        Config(;
                            x = no_markup_purchase_quantity_data_to_plot,
                            y = no_markup_purchase_price_data_to_plot,
                            name = name,
                            line = Dict("color" => _get_plot_color(color_idx)),
                            type = "line",
                        ),
                    )
                end

                # Add demand lines
                demand_lines = _demand_lines_to_plot(
                    ex_post_demand,
                    demand_time_index;
                    include_first_scenario = plot_virtual_reservoir_data,
                )
                for (line_type, subscenario) in demand_lines
                    demand = _demand_in_line(ex_ante_demand, ex_post_demand, demand_time_index, subscenario)
                    if demand_as_curve
                        # From the inelastic demand, with one step per demand offer of the clearing of the line
                        inelastic_demand = _demand_in_line(
                            ex_ante_inelastic_demand,
                            ex_post_inelastic_demand,
                            demand_time_index,
                            subscenario,
                        )
                        line_offer_quantity, line_offer_price = demand_offer_quantity, demand_offer_price
                        if !isnothing(subscenario) && !isnothing(bg_ex_post_quantity_data)
                            ex_post_subscenario = min(subscenario, size(bg_ex_post_quantity_data, 4))
                            line_offer_quantity, line_offer_price = _demand_offers(
                                vec(bg_ex_post_quantity_data[:, :, subperiod, ex_post_subscenario]),
                                bg_price,
                            )
                        end
                        demand_quantity_data_to_plot, demand_price_data_to_plot = _demand_curve_points(
                            inelastic_demand,
                            demand,
                            line_offer_quantity,
                            line_offer_price;
                            max_price = y_axis_limits[2],
                            min_price = y_axis_limits[1],
                        )
                    else
                        demand_quantity_data_to_plot = range(demand, demand; length = 100)
                        demand_price_data_to_plot = y_axis_range
                    end
                    color_idx += 1
                    demand_line_config = Config(;
                        x = demand_quantity_data_to_plot,
                        y = demand_price_data_to_plot,
                        name = get_name(inputs, "$(line_type)_$demand_name"),
                        line = Dict("color" => _get_plot_color(color_idx), "dash" => "4px,4px"),
                        type = "line",
                        mode = "lines",
                    )
                    # The demand curve keeps the default (x, y) tooltip, since its price varies along the line
                    if !demand_as_curve
                        demand_line_config.hovertemplate = "%{x} MWh"
                    end
                    push!(configs, demand_line_config)
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

                file_name = if demand_as_curve
                    "bid_curve_demand_curve_subperiod_$subperiod.html"
                else
                    "bid_curve_subperiod_$subperiod.html"
                end
                _save_plot(Plot(configs, main_configuration), joinpath(plots_path, file_name))
            end
        end
    end

    return nothing
end

# Demand to plot against the bid curve, and whether it is net of renewable generation.
# Renewable generation is removed from the demand, except for the renewable units that bid through bidding groups,
# whose generation is already part of the bids.
function _get_bid_curve_demands(inputs::AbstractInputs; @nospecialize(filters::Vector{<:Function} = Function[]))
    ex_ante_demand, ex_post_demand = get_demands_to_plot(inputs; filters)
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
    return ex_ante_demand, ex_post_demand, demand_name
end

# Quantity and price of every offer (label and segment) in the subperiod, averaged across scenarios
function _mean_offers_in_subperiod(quantity_data::AbstractArray, price_data::AbstractArray, subperiod::Int)
    quantity = Float64[]
    price = Float64[]
    for segment in axes(quantity_data, 2)
        for label_index in axes(quantity_data, 1)
            push!(quantity, mean(quantity_data[label_index, segment, subperiod, :]))
            push!(price, mean(price_data[label_index, segment, subperiod, :]))
        end
    end
    return quantity, price
end

# Split the offers into sell and purchase offers, both with positive quantities.
# Negative virtual reservoir quantities are purchase offers. Negative bidding group quantities are demand offers
# if some demand unit bids through a bidding group, and purchase offers otherwise. Demand offers are left out
# when the demand is plotted as a curve, and become demand cut offers (sell offers at the same price) otherwise.
function _split_sell_and_purchase_offers(
    bg_quantity::Vector{Float64},
    bg_price::Vector{Float64},
    vr_quantity::Vector{Float64},
    vr_price::Vector{Float64};
    has_demand_offers::Bool,
    demand_as_curve::Bool,
)
    sell_quantity = Float64[]
    sell_price = Float64[]
    purchase_quantity = Float64[]
    purchase_price = Float64[]
    for (quantity, price, is_bidding_group) in ((bg_quantity, bg_price, true), (vr_quantity, vr_price, false))
        for (q, p) in zip(quantity, price)
            if q >= 0
                push!(sell_quantity, q)
                push!(sell_price, p)
            elseif !(is_bidding_group && has_demand_offers)
                push!(purchase_quantity, -q)
                push!(purchase_price, p)
            elseif !demand_as_curve
                push!(sell_quantity, -q)
                push!(sell_price, p)
            end
        end
    end
    return (; sell_quantity, sell_price, purchase_quantity, purchase_price)
end

# Stepped points of an offer curve, accumulating the offers in increasing price order
function _offer_curve_points(quantity::Vector{Float64}, price::Vector{Float64})
    sort_order = sortperm(price)
    cumulative_quantity = cumsum(quantity[sort_order])
    sorted_price = price[sort_order]
    quantity_data_to_plot = Float64[0.0]
    price_data_to_plot = Float64[0.0]
    for (q, p) in zip(cumulative_quantity, sorted_price)
        # old point
        push!(quantity_data_to_plot, quantity_data_to_plot[end])
        push!(price_data_to_plot, p)
        # new point
        push!(quantity_data_to_plot, q)
        push!(price_data_to_plot, p)
    end
    return quantity_data_to_plot, price_data_to_plot
end

# Demand offers among the bidding group offers, which are the ones with negative quantities, with positive quantities
function _demand_offers(bg_quantity::Vector{Float64}, bg_price::Vector{Float64})
    demand_offer_indices = findall(q -> q < 0, bg_quantity)
    return -bg_quantity[demand_offer_indices], bg_price[demand_offer_indices]
end

# Quantity bids of each subscenario of the ex-post clearing, which adjusts the bids of each bidding group by its ex-post
# adjustment mode, as [label, segment, subperiod, subscenario] in MWh averaged across scenarios, with the labels in the
# order of `labels`. Returns `nothing` if the ex-post clearing did not write them.
function _read_ex_post_quantity_bids(
    inputs::AbstractInputs,
    labels::AbstractVector{<:AbstractString},
    num_bid_segments::Int,
)
    file_path = joinpath(output_path(inputs), "bidding_group_energy_bid_ex_post_period_$(inputs.args.period).csv")
    if !isfile(file_path)
        return nothing
    end
    # Dimensions: label, bid segment, subperiod, subscenario, scenario, period
    data, metadata = read_timeseries_file(file_path)
    label_indexes = indexin(labels, metadata.labels)
    if any(isnothing, label_indexes) || size(data, 2) != num_bid_segments
        return nothing
    end
    data = data[Int.(label_indexes), :, :, :, :, 1]
    # The ex-post bids are written in GWh
    return dropdims(mean(data; dims = 5); dims = 5) ./ MW_to_GW()
end

# Stepped points of a demand curve: a vertical segment at the inelastic demand from `max_price`, then one step per
# demand offer in decreasing price order, and a vertical segment down to `min_price` where the offers end.
# The offers stop at the total demand, since the clearing does not let them buy more than the elastic demand
function _demand_curve_points(
    inelastic_demand::Real,
    total_demand::Real,
    demand_offer_quantity::Vector{Float64},
    demand_offer_price::Vector{Float64};
    max_price::Real,
    min_price::Real,
)
    sort_order = sortperm(demand_offer_price; rev = true)
    quantity_data_to_plot = Float64[inelastic_demand]
    price_data_to_plot = Float64[max_price]
    for (quantity, price) in zip(demand_offer_quantity[sort_order], demand_offer_price[sort_order])
        if quantity_data_to_plot[end] >= total_demand
            break
        end
        # old point
        push!(quantity_data_to_plot, quantity_data_to_plot[end])
        push!(price_data_to_plot, price)
        # new point
        push!(quantity_data_to_plot, min(quantity_data_to_plot[end] + quantity, total_demand))
        push!(price_data_to_plot, price)
    end
    push!(quantity_data_to_plot, quantity_data_to_plot[end])
    push!(price_data_to_plot, min_price)
    return quantity_data_to_plot, price_data_to_plot
end

# Demand lines in the time index, as pairs of line type and ex-post subscenario: the subscenarios with the minimum and
# maximum demand, the average demand, which is the ex-ante demand and has no subscenario, and optionally the first
# subscenario
function _demand_lines_to_plot(
    ex_post_demand::AbstractMatrix{<:Real},
    demand_time_index::Int;
    include_first_scenario::Bool,
)
    demand_lines = Tuple{String, Union{Int, Nothing}}[
        ("minimum", argmin(ex_post_demand[:, demand_time_index])),
        ("average", nothing),
        ("maximum", argmax(ex_post_demand[:, demand_time_index])),
    ]
    if include_first_scenario
        push!(demand_lines, ("first_scenario", 1))
    end
    return demand_lines
end

# Demand of a demand line in the time index: the ex-ante demand if the line has no subscenario, and the ex-post demand
# of its subscenario otherwise
function _demand_in_line(
    ex_ante_demand::AbstractVector{<:Real},
    ex_post_demand::AbstractMatrix{<:Real},
    demand_time_index::Int,
    subscenario::Union{Int, Nothing},
)
    if isnothing(subscenario)
        return ex_ante_demand[demand_time_index]
    end
    return ex_post_demand[subscenario, demand_time_index]
end

# Base of bars stacked on bars that span from `base` to `base + y`: positive values are stacked above the top of the
# bars and negative values below their bottom
function _stacked_bar_base(
    values::AbstractVector{<:Real},
    base::AbstractVector{<:Real},
    y::AbstractVector{<:Real},
)
    return ifelse.(values .>= 0, max.(base, base .+ y), min.(base, base .+ y))
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
    cut_elastic_demand::Union{Matrix{Float64}, Nothing} = nothing,
    # If false and there is cut elastic demand, the bidding group data is not plotted, leaving only the cut elastic demand
    plot_attended_elastic_demand::Bool = true,
)
    if isempty(bg_file_path) && isempty(vr_file_path)
        error("At least one of bg_file_path or vr_file_path must be provided")
    end
    if !isnothing(cut_elastic_demand)
        @assert !isempty(bg_file_path) "Cut elastic demand plotting requires bidding group data"
    end
    # TODO: The bidding group data sums every bidding group of the asset owner, so if the asset owner also has
    # generation (e.g. renewable units in the same bidding group as the elastic demand), it is hidden together with the
    # attended elastic demand, or labeled as attended elastic demand. Only the attended elastic demand should be split.
    plot_bg_data = isnothing(cut_elastic_demand) || plot_attended_elastic_demand

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
            if !isnothing(cut_elastic_demand)
                cut_elastic_demand = round.(cut_elastic_demand; digits = 1)
            end
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

    # The fixed component is bidding group data, so it is left out when only the cut elastic demand is plotted
    if !plot_bg_data
        fixed_component = Float64[]
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
            # VR data has no subperiod dimension, so it is stored at subperiod index 1.
            # Divide by num_subperiods to distribute the total evenly across subperiod bars.
            vr_y_values = vr_data[1, :] ./ num_subperiods
            vr_y_positive = max.(vr_y_values, 0.0)
        end

        if !isempty(bg_file_path)
            if !isnothing(cut_elastic_demand)
                # The bidding group generation is the attended elastic demand, with a negative sign
                variable_component_name = get_name(inputs, "attended_elastic_demand")
            elseif !isempty(vr_file_path)
                variable_component_name = title * get_name(inputs, "bidding_group_suffix")
            end
            if num_subperiods > 1
                variable_component_name *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end

            # Stack BG on top of positive VR
            bg_y_values = plot_bg_data ? bg_data[subperiod, :] : zeros(Float64, num_subscenarios)
            bg_base = isempty(vr_file_path) ? zeros(Float64, num_subscenarios) : vr_y_positive

            if plot_bg_data
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

            # Stack the cut elastic demand on the attended elastic demand: below it when negative, as in the generation,
            # where the bar then reaches the total elastic demand, and above it when positive
            if !isnothing(cut_elastic_demand)
                cut_component_name = get_name(inputs, "cut_elastic_demand")
                if num_subperiods > 1
                    cut_component_name *= " - $(get_name(inputs, "subperiod")) $subperiod"
                end
                cut_y_values = cut_elastic_demand[subperiod, :]
                push!(
                    configs,
                    Config(;
                        x = 1:num_subscenarios,
                        y = cut_y_values,
                        base = _stacked_bar_base(cut_y_values, bg_base, bg_y_values),
                        name = cut_component_name,
                        marker = Dict("color" => _get_plot_color(subperiod; light_shade = true)),
                        type = "bar",
                        customdata = cut_y_values,
                        hovertemplate = "(%{customdata})",
                    ),
                )
            end
        end
        if !isempty(vr_file_path)
            vr_component_name = title
            if !isempty(bg_file_path)
                vr_component_name *= get_name(inputs, "virtual_reservoir_suffix")
            end
            if num_subperiods > 1
                vr_component_name *= " - $(get_name(inputs, "subperiod")) $subperiod"
            end

            # vr_y_positive already calculated above; now calculate negative
            # VR data has no subperiod dimension, so it is stored at subperiod index 1.
            # Divide by num_subperiods to distribute the total evenly across subperiod bars.
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
    merge_bg_and_vr::Bool = false,
    plot_cut_elastic_demand::Bool = false,
    # If false, the bidding group data is not plotted for the asset owners with cut elastic demand, leaving only the
    # cut elastic demand
    plot_attended_elastic_demand::Bool = true,
)
    if isempty(bg_file_path) && isempty(vr_file_path)
        error("At least one of bg_file_path or vr_file_path must be provided")
    end
    if plot_cut_elastic_demand
        @assert !isempty(bg_file_path) "Cut elastic demand plotting requires bidding group data"
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

    if merge_bg_and_vr && !isempty(bg_file_path) && !isempty(vr_file_path)
        @assert vr_num_subscenarios == num_subscenarios "Mismatch between bidding group and virtual reservoir subscenarios"
        # VR data has no subperiod dimension, so it is stored at subperiod index 1.
        # Divide by num_subperiods to distribute the total evenly across subperiod bars.
        bg_data = bg_data .+ vr_data[:, 1:1, :] ./ num_subperiods
        if round_data
            bg_data = round.(bg_data; digits = 1)
        end
        # From here on, the merged data is plotted as a single bar per asset owner
        vr_file_path = ""
    end

    asset_owner_indexes = index_of_elements(inputs, AssetOwner)

    # Cut elastic demand of the asset owners that have elastic demand
    cut_elastic_demand = Dict{Int, Matrix{Float64}}()
    if plot_cut_elastic_demand
        for asset_owner_index in asset_owner_indexes
            cut = get_cut_elastic_demand_to_plot(inputs, bg_file_path; asset_owner_index)
            if !isnothing(cut)
                cut_elastic_demand[asset_owner_index] = round_data ? round.(cut; digits = 1) : cut
            end
        end
    end

    for subperiod in 1:num_subperiods
        # First pass: collect all positive VR cumulative sums per x position for stacking BG on top
        positive_vr_cumsum = Dict{Int, Vector{Float64}}()

        for asset_owner_index in asset_owner_indexes
            x_positions =
                asset_owner_index:(length(asset_owner_indexes)+1):num_subscenarios*(length(asset_owner_indexes)+1)

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
            x_positions =
                asset_owner_index:(length(asset_owner_indexes)+1):num_subscenarios*(length(asset_owner_indexes)+1)

            if !isempty(bg_file_path)
                has_cut_elastic_demand = haskey(cut_elastic_demand, asset_owner_index)
                # TODO: Same as in plot_agent_output, the generation of an asset owner with elastic demand is hidden
                # together with the attended elastic demand, or labeled as attended elastic demand
                plot_bg_data = !has_cut_elastic_demand || plot_attended_elastic_demand
                ao_label_for_bg = ao_label
                if has_cut_elastic_demand
                    # The bidding group generation is the attended elastic demand, with a negative sign
                    ao_label_for_bg *= " - $(get_name(inputs, "attended_elastic_demand"))"
                elseif !isempty(vr_file_path)
                    ao_label_for_bg *= get_name(inputs, "bidding_group_suffix")
                end
                bg_y_values = if plot_bg_data
                    vcat(bg_data[asset_owner_index, subperiod, :], 0.0)
                else
                    zeros(Float64, num_subscenarios + 1)
                end

                # Stack BG on top of positive VR
                bg_base = zeros(Float64, length(bg_y_values))
                if !isempty(vr_file_path)
                    for (idx, x_pos) in enumerate(x_positions)
                        if haskey(positive_vr_cumsum, x_pos)
                            bg_base[idx] = positive_vr_cumsum[x_pos][idx]
                        end
                    end
                end

                if plot_bg_data
                    push!(
                        configs,
                        Config(;
                            x = x_positions,
                            y = bg_y_values,
                            base = bg_base,
                            name = ao_label_for_bg,
                            marker = Dict("color" => _get_plot_color(asset_owner_index)),
                            type = "bar",
                            width = 1,
                            customdata = bg_y_values,
                            hovertemplate = "(%{customdata})",
                        ),
                    )
                end

                # Stack the cut elastic demand on the attended elastic demand: below it when negative, as in the
                # generation, where the bar then reaches the total elastic demand, and above it when positive
                if has_cut_elastic_demand
                    cut_y_values = vcat(cut_elastic_demand[asset_owner_index][subperiod, :], 0.0)
                    push!(
                        configs,
                        Config(;
                            x = x_positions,
                            y = cut_y_values,
                            base = _stacked_bar_base(cut_y_values, bg_base, bg_y_values),
                            name = "$ao_label - $(get_name(inputs, "cut_elastic_demand"))",
                            marker = Dict("color" => _get_plot_color(asset_owner_index; light_shade = true)),
                            type = "bar",
                            width = 1,
                            customdata = cut_y_values,
                            hovertemplate = "(%{customdata})",
                        ),
                    )
                end
            end

            if !isempty(vr_file_path)
                ao_label_for_vr = ao_label
                if !isempty(bg_file_path)
                    ao_label_for_vr *= get_name(inputs, "virtual_reservoir_suffix")
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
                            width = 1,
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
                            width = 1,
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
