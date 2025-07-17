#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

"""
    _extract_bus_label(gen_label::String) -> String

Extract the bus label from a generation label.

# Arguments
- `gen_label`: Generation label in format "bg_X - bus_Y"

# Returns
- The bus label (e.g., "bus_Y")

# Throws
- Error if the generation label format is invalid
"""
function _extract_bus_label(gen_label::String)
    parts = split(gen_label, " - ")
    if length(parts) != 2
        error("Invalid generation label format: $gen_label. Expected format: 'bg_X - bus_Y'")
    end
    return parts[2]  # This is the "bus_Y" part
end

"""
    _extract_bus_idx(bus_label::String, bus_collection) -> Int

Get the index of a bus given its label.

# Arguments
- `bus_label`: The bus label to look up
- `bus_collection`: The bus collection containing labels and indices

# Returns
- The index of the bus in the collection

# Throws
- Error if the bus label is not found
"""
function _extract_bus_idx(gen_label, bus_collection)
    bus_label = _extract_bus_label(gen_label)
    bus_index = findfirst(x -> x == bus_label, bus_collection.label)
    if bus_index === nothing
        error("Bus '$bus_label' not found in bus collection. Available buses: $(join(bus_collection.label, ", "))")
    end
    return bus_index
end

"""
    get_spot_prices(reader, bus_collection, generation_labels, network_representation)

Get spot prices for all bidding groups based on the network representation.

# Arguments
- `reader`: The reader containing spot price data
- `bus_collection`: The bus collection with zone indices and labels
- `generation_labels`: Array of generation labels in format "bg_X - bus_Y"
- `network_representation`: The network representation type (ZONAL or NODAL)

# Returns
- Vector of spot prices corresponding to each generation label
"""
function get_spot_prices(reader, bus_collection, generation_labels, network_representation)
    # Pre-allocate array for spot prices
    spot_prices = similar(reader.data, length(generation_labels))

    # Process each bidding group
    for (i, gen_label) in enumerate(generation_labels)
        # Extract bus label and get its index
        bus_idx = _extract_bus_idx(gen_label, bus_collection)

        # Get the appropriate location index based on network representation
        location_idx = if network_representation == Configurations_NetworkRepresentation.ZONAL
            bus_collection.zone_index[bus_idx]  # Zonal: use zone index
        else
            bus_idx                             # Nodal: use bus index directly
        end

        # Store the spot price
        spot_prices[i] = reader.data[location_idx]
    end

    return spot_prices
end

# Helper functions for price bounds
_check_floor(price::Real, floor::Real) = !is_null(floor) ? max(price, floor) : price
_check_cap(price::Real, cap::Real) = !is_null(cap) ? min(price, cap) : price

function _write_revenue_without_subscenarios(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    writer_without_subscenarios::Quiver.Writer,
    generation_ex_ante_reader::Quiver.Reader,
    spot_ex_ante_reader::Quiver.Reader,
    is_profile::Bool,
)
    num_periods, num_scenarios, num_subperiods, num_bid_segments =
        generation_ex_ante_reader.metadata.dimension_size

    generation_labels = generation_ex_ante_reader.metadata.labels
    spot_price_labels = spot_ex_ante_reader.metadata.labels
    num_bidding_groups_times_buses = length(generation_labels)

    dim_name = is_profile ? :profile : :bid_segment

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                sum_generation = zeros(num_bidding_groups_times_buses)
                for bid_segment in 1:num_bid_segments
                    Quiver.goto!(
                        generation_ex_ante_reader;
                        period,
                        scenario,
                        subperiod = subperiod,
                        Symbol(dim_name) => bid_segment,
                    )
                    sum_generation .+= generation_ex_ante_reader.data
                end

                # Position the reader for the current period/scenario/subperiod
                Quiver.goto!(spot_ex_ante_reader; period, scenario, subperiod = subperiod)

                # Get network representation type once
                net_rep = network_representation_ex_ante_commercial(inputs)

                # Get spot prices for all bidding groups based on network representation
                spot_price_data = get_spot_prices(
                    spot_ex_ante_reader,
                    inputs.collections.bus,
                    generation_labels,
                    net_rep,
                )

                Quiver.write!(
                    writer_without_subscenarios,
                    sum_generation .* apply_lmc_bounds(spot_price_data, inputs) / MW_to_GW(); # GWh to MWh
                    period,
                    scenario,
                    subperiod = subperiod,
                )
            end
        end
    end
    Quiver.close!(writer_without_subscenarios)
    # Close readers because they reached the end of the file.
    Quiver.close!(generation_ex_ante_reader)
    Quiver.close!(spot_ex_ante_reader)
    return nothing
end

function _write_revenue_with_subscenarios(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    writer_with_subscenarios::Quiver.Writer,
    generation_ex_ante_reader::Union{Quiver.Reader, Nothing},
    generation_ex_post_reader::Quiver.Reader,
    spot_ex_ante_reader::Union{Quiver.Reader, Nothing},
    spot_ex_post_reader::Quiver.Reader,
    is_profile::Bool,
)
    num_periods, num_scenarios, num_subscenarios, num_subperiods, num_bid_segments =
        generation_ex_post_reader.metadata.dimension_size

    generation_labels = generation_ex_post_reader.metadata.labels
    spot_price_labels = spot_ex_post_reader.metadata.labels
    num_bidding_groups_times_buses = length(generation_labels)

    dim_name = is_profile ? :profile : :bid_segment

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    sum_generation = zeros(num_bidding_groups_times_buses)
                    for bid_segment in 1:num_bid_segments
                        Quiver.goto!(
                            generation_ex_post_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                            Symbol(dim_name) => bid_segment,
                        )
                        if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
                            # Just read the ex-ante generation once per subscenario
                            Quiver.goto!(
                                generation_ex_ante_reader;
                                period,
                                scenario,
                                subperiod = subperiod,
                                Symbol(dim_name) => bid_segment,
                            )
                            # In the double settlement, the ex-post generation is the difference between the ex-post and ex-ante generation
                            # The total revenue is the sum of the ex-ante and ex-post revenue
                            sum_generation .+= generation_ex_post_reader.data .- generation_ex_ante_reader.data
                        else
                            sum_generation .+= generation_ex_post_reader.data
                        end
                    end

                    # Select the appropriate reader based on settlement type
                    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE
                        Quiver.goto!(spot_ex_ante_reader; period, scenario, subperiod = subperiod)
                        current_reader = spot_ex_ante_reader
                        net_rep = network_representation_ex_ante_commercial(inputs)
                    else
                        Quiver.goto!(
                            spot_ex_post_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                        current_reader = spot_ex_post_reader
                        net_rep = network_representation_ex_post_commercial(inputs)
                    end

                    # Get spot prices for all bidding groups based on network representation
                    spot_price_data = get_spot_prices(
                        current_reader,
                        inputs.collections.bus,
                        generation_labels,
                        net_rep,
                    )

                    Quiver.write!(
                        writer_with_subscenarios,
                        sum_generation .* apply_lmc_bounds(spot_price_data, inputs) / MW_to_GW(); # GWh to MWh
                        period,
                        scenario,
                        subscenario,
                        subperiod = subperiod,
                    )
                end
            end
        end
    end
    Quiver.close!(writer_with_subscenarios)
    # Close readers because they reached the end of the file.
    if settlement_type(inputs) != IARA.Configurations_FinancialSettlementType.EX_POST
        Quiver.close!(generation_ex_ante_reader)
        Quiver.close!(spot_ex_ante_reader)
    end
    Quiver.close!(generation_ex_post_reader)
    Quiver.close!(spot_ex_post_reader)
    return nothing
end

"""
    post_processing_bidding_group_revenue(inputs::Inputs, outputs_post_processing::Outputs, model_outputs_time_serie::OutputReaders, run_time_options::RunTimeOptions)

Post-process the bidding group revenue data, based on the generation data and the marginal cost data.
"""
function post_processing_bidding_group_revenue(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
)
    outputs_dir = output_path(inputs)
    post_processing_dir = post_processing_path(inputs)

    if settlement_type(inputs) != IARA.Configurations_FinancialSettlementType.EX_POST
        bidding_group_generation_ex_ante_files =
            get_generation_files(outputs_dir, post_processing_path(inputs); from_ex_post = false)
        bidding_group_load_marginal_cost_ex_ante_files = get_load_marginal_files(outputs_dir; from_ex_post = false)
    end
    bidding_group_generation_ex_post_files =
        get_generation_files(outputs_dir, post_processing_path(inputs); from_ex_post = true)
    bidding_group_load_marginal_cost_ex_post_files = get_load_marginal_files(outputs_dir; from_ex_post = true)

    if length(bidding_group_load_marginal_cost_ex_post_files) > 1
        error(
            "Multiple load marginal cost files found: $bidding_group_load_marginal_cost_ex_ante_files",
        )
    end

    if settlement_type(inputs) != IARA.Configurations_FinancialSettlementType.EX_POST
        if length(bidding_group_load_marginal_cost_ex_ante_files) > 1
            error(
                "Multiple load marginal cost files found: $bidding_group_load_marginal_cost_ex_ante_files",
            )
        end
    end

    number_of_files = length(bidding_group_generation_ex_post_files)
    outputs_dir = output_path(inputs)

    for i in 1:number_of_files
        if settlement_type(inputs) != IARA.Configurations_FinancialSettlementType.EX_POST
            geneneration_ex_ante_file = get_filename(bidding_group_generation_ex_ante_files[i])
            spot_price_ex_ante_file = get_filename(bidding_group_load_marginal_cost_ex_ante_files[1])
            geneneration_ex_ante_reader =
                open_time_series_output(
                    inputs,
                    model_outputs_time_serie,
                    geneneration_ex_ante_file;
                    convert_to_binary = true,
                )
            spot_price_ex_ante_reader =
                open_time_series_output(
                    inputs,
                    model_outputs_time_serie,
                    spot_price_ex_ante_file;
                    convert_to_binary = true,
                )
        else
            geneneration_ex_ante_reader = nothing
            spot_price_ex_ante_reader = nothing
        end
        spot_price_ex_post_file = get_filename(bidding_group_load_marginal_cost_ex_post_files[1])
        geneneration_ex_post_file = get_filename(bidding_group_generation_ex_post_files[i])
        spot_price_ex_post_reader =
            open_time_series_output(inputs, model_outputs_time_serie, spot_price_ex_post_file)
        geneneration_ex_post_reader =
            open_time_series_output(inputs, model_outputs_time_serie, geneneration_ex_post_file)

        is_profile = occursin("profile", basename(geneneration_ex_post_file))

        time_series_path_with_subscenarios = "bidding_group_revenue"
        time_series_path_without_subscenarios = "bidding_group_revenue"
        file_type_with_subscenarios =
            settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE ? "_ex_ante" : "_ex_post"
        file_type_without_subscenarios = "_ex_ante"

        if is_profile
            time_series_path_with_subscenarios *= "_profile"
            time_series_path_without_subscenarios *= "_profile"
        else
            time_series_path_with_subscenarios *= "_independent"
            time_series_path_without_subscenarios *= "_independent"
        end

        time_series_path_with_subscenarios *= file_type_with_subscenarios
        time_series_path_without_subscenarios *= file_type_without_subscenarios

        # The revenue is summed over all bid segments / profiles, so we drop the last dimension
        initialize!(
            QuiverOutput,
            outputs_post_processing;
            inputs,
            output_name = time_series_path_with_subscenarios,
            dimensions = ["period", "scenario", "subscenario", "subperiod"],
            unit = "\$",
            labels = geneneration_ex_post_reader.metadata.labels,
            run_time_options,
            dir_path = post_processing_dir,
        )
        writer_with_subscenarios =
            get_writer(outputs_post_processing, inputs, run_time_options, time_series_path_with_subscenarios)

        _write_revenue_with_subscenarios(
            inputs,
            run_time_options,
            writer_with_subscenarios,
            geneneration_ex_ante_reader,
            geneneration_ex_post_reader,
            spot_price_ex_ante_reader,
            spot_price_ex_post_reader,
            is_profile,
        )

        if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
            geneneration_ex_ante_file = get_filename(bidding_group_generation_ex_ante_files[i])
            spot_price_ex_ante_file = get_filename(bidding_group_load_marginal_cost_ex_ante_files[1])
            geneneration_ex_ante_reader =
                open_time_series_output(inputs, model_outputs_time_serie, geneneration_ex_ante_file)
            spot_price_ex_ante_reader =
                open_time_series_output(inputs, model_outputs_time_serie, spot_price_ex_ante_file)

            initialize!(
                QuiverOutput,
                outputs_post_processing;
                inputs,
                output_name = time_series_path_without_subscenarios,
                dimensions = ["period", "scenario", "subperiod"],
                unit = "\$",
                labels = geneneration_ex_ante_reader.metadata.labels,
                run_time_options,
                dir_path = post_processing_dir,
            )
            writer_without_subscenarios =
                get_writer(outputs_post_processing, inputs, run_time_options, time_series_path_without_subscenarios)

            _write_revenue_without_subscenarios(
                inputs,
                run_time_options,
                writer_without_subscenarios,
                geneneration_ex_ante_reader,
                spot_price_ex_ante_reader,
                is_profile,
            )
        end
    end
    return
end

function apply_lmc_bounds(lmc::Vector{<:AbstractFloat}, inputs::Inputs)
    spot_price_cap = inputs.collections.configurations.spot_price_cap
    spot_price_floor = inputs.collections.configurations.spot_price_floor

    lmc = _check_floor.(lmc, spot_price_floor)
    lmc = _check_cap.(lmc, spot_price_cap)
    return lmc
end

function get_generation_files(output_dir::String, post_processing_dir::String; from_ex_post::Bool)
    files = get_generation_files(output_dir; from_ex_post = from_ex_post)
    if isempty(files)
        files = get_generation_files(post_processing_dir; from_ex_post = from_ex_post)
    end
    return files
end

function get_generation_files(path::String; from_ex_post::Bool)
    from_ex_post_string = from_ex_post ? "ex_post" : "ex_ante"

    commercial_generation_files = filter(
        x ->
            occursin("bidding_group_generation", x) &&
                occursin(from_ex_post_string * "_commercial", x) &&
                get_file_ext(x) == ".csv",
        readdir(path),
    )

    physical_generation_files = filter(
        x ->
            occursin("bidding_group_generation", x) &&
                occursin(from_ex_post_string * "_physical", x) &&
                get_file_ext(x) == ".csv",
        readdir(path),
    )

    if isempty(physical_generation_files)
        return joinpath.(path, commercial_generation_files)
    else
        return joinpath.(path, physical_generation_files)
    end
end

function get_load_marginal_files(path::String; from_ex_post::Bool)
    from_ex_post_string = from_ex_post ? "ex_post" : "ex_ante"

    commercial_lmc_files = filter(
        x ->
            occursin("load_marginal_cost", x) &&
                occursin(from_ex_post_string * "_commercial", x) && get_file_ext(x) == ".csv", readdir(path),
    )

    physical_lmc_files = filter(
        x ->
            occursin("load_marginal_cost", x) &&
                occursin(from_ex_post_string * "_physical", x) && get_file_ext(x) == ".csv", readdir(path))

    if isempty(commercial_lmc_files)
        return joinpath.(path, physical_lmc_files)
    else
        return joinpath.(path, commercial_lmc_files)
    end
end

function _total_revenue(
    total_revenue_writer::Quiver.Writer,
    ex_ante_reader::Quiver.Reader,
    ex_post_reader::Quiver.Reader,
)
    num_periods, num_scenarios, num_subscenarios, num_subperiods = ex_post_reader.metadata.dimension_size

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    Quiver.goto!(ex_ante_reader; period, scenario, subperiod = subperiod)
                    Quiver.goto!(ex_post_reader; period, scenario, subscenario = subscenario, subperiod = subperiod)

                    total_revenue = ex_ante_reader.data .+ ex_post_reader.data

                    Quiver.write!(
                        total_revenue_writer,
                        total_revenue;
                        period,
                        scenario,
                        subscenario = subscenario,
                        subperiod = subperiod,
                    )
                end
            end
        end
    end
    Quiver.close!(total_revenue_writer)
    Quiver.close!(ex_ante_reader)
    Quiver.close!(ex_post_reader)
    return
end

function _join_independent_and_profile_bid(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    post_processing_dir = post_processing_path(inputs)
    temp_dir = joinpath(output_path(inputs), "temp")
    if !isdir(temp_dir)
        mkpath(temp_dir)
    end

    bidding_group_bus_labels = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.bidding_group,
        inputs.collections.bus;
        index_getter = all_buses,
        filters_to_apply_in_first_collection = [has_generation_besides_virtual_reservoirs],
    )

    impl = Quiver.csv
    # If there are no independent or profile bids, generate a zero file.
    # Check for the existence of ex ante files, which are present if the settlement type is ex ante or dual.
    if settlement_type(inputs) in
       [IARA.Configurations_FinancialSettlementType.EX_ANTE, IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT]
        # For ex ante settlement type, the final revenue is calculated as the product of ex_post generation and ex_ante spot price.
        # For double settlement type, the ex_ante revenue is the product of ex_ante generation and ex_ante spot price.
        has_subscenarios = settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE
        filepath_independent = joinpath(
            post_processing_dir,
            "bidding_group_revenue_independent_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
        )

        filepath_profile = joinpath(
            post_processing_dir,
            "bidding_group_revenue_profile_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
        )
        if !(has_any_simple_bids(inputs) || clearing_has_physical_variables(inputs, run_time_options))
            filepath_independent = joinpath(
                temp_dir,
                "bidding_group_revenue_independent_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
            )
            create_zero_file(
                inputs,
                run_time_options,
                "bidding_group_revenue_independent_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
                bidding_group_bus_labels,
                impl,
                "\$";
                has_subscenarios = has_subscenarios,
            )
        end
        if !has_any_profile_bids(inputs)
            filepath_profile = joinpath(
                temp_dir,
                "bidding_group_revenue_profile_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
            )
            create_zero_file(
                inputs,
                run_time_options,
                "bidding_group_revenue_profile_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
                bidding_group_bus_labels,
                impl,
                "\$";
                has_subscenarios = has_subscenarios,
            )
        end

        file_revenue_ex_ante = joinpath(
            post_processing_dir,
            "bidding_group_revenue_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
        )

        Quiver.apply_expression(
            file_revenue_ex_ante,
            [filepath_independent, filepath_profile],
            +,
            Quiver.csv;
            digits = 6,
        )
    end
    # Check for the existence of ex_post files, which are present if the settlement type is ex post or dual.
    if settlement_type(inputs) in
       [IARA.Configurations_FinancialSettlementType.EX_POST, IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT]
        filepath_independent = joinpath(
            post_processing_dir,
            "bidding_group_revenue_independent_ex_post" * run_time_file_suffixes(inputs, run_time_options),
        )
        filepath_profile = joinpath(
            post_processing_dir,
            "bidding_group_revenue_profile_ex_post" * run_time_file_suffixes(inputs, run_time_options),
        )
        if !(has_any_simple_bids(inputs) || clearing_has_physical_variables(inputs, run_time_options))
            filepath_independent = joinpath(
                temp_dir,
                "bidding_group_revenue_independent_ex_post" * run_time_file_suffixes(inputs, run_time_options),
            )
            create_zero_file(
                inputs,
                run_time_options,
                "bidding_group_revenue_independent_ex_post" * run_time_file_suffixes(inputs, run_time_options),
                bidding_group_bus_labels,
                impl,
                "\$";
                has_subscenarios = true,
            )
        end
        if !has_any_profile_bids(inputs)
            filepath_profile = joinpath(
                temp_dir,
                "bidding_group_revenue_profile_ex_post" * run_time_file_suffixes(inputs, run_time_options),
            )
            create_zero_file(
                inputs,
                run_time_options,
                "bidding_group_revenue_profile_ex_post" * run_time_file_suffixes(inputs, run_time_options),
                bidding_group_bus_labels,
                impl,
                "\$";
                has_subscenarios = true,
            )
        end

        file_revenue_ex_post = joinpath(
            post_processing_dir,
            "bidding_group_revenue_ex_post" * run_time_file_suffixes(inputs, run_time_options),
        )

        Quiver.apply_expression(
            file_revenue_ex_post,
            [filepath_independent, filepath_profile],
            +,
            impl;
            digits = 6,
        )
    end

    return nothing
end

"""
    post_processing_bidding_group_total_revenue(inputs::Inputs, outputs_post_processing::Outputs, model_outputs_time_serie::OutputReaders, run_time_options::RunTimeOptions)

Post-process the total revenue data, based on the ex-ante and ex-post revenue data.
"""
function post_processing_bidding_group_total_revenue(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
)
    outputs_dir = output_path(inputs)
    post_processing_dir = post_processing_path(inputs)
    tempdir = joinpath(path_case(inputs), "temp")

    period_suffix = if is_single_period(inputs)
        "_period_$(inputs.args.period)"
    else
        ""
    end

    # Summing ex_ante and ex_post for double settlement

    revenue_ex_ante_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(post_processing_dir, "bidding_group_revenue_ex_ante" * period_suffix);
        convert_to_binary = true,
    )

    revenue_ex_post_reader =
        open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(post_processing_dir, "bidding_group_revenue_ex_post" * period_suffix),
        )

    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = "bidding_group_total_revenue",
        dimensions = ["period", "scenario", "subscenario", "subperiod"],
        unit = "\$",
        labels = revenue_ex_ante_reader.metadata.labels,
        run_time_options,
        dir_path = post_processing_dir,
    )
    total_revenue_writer = get_writer(outputs_post_processing, inputs, run_time_options, "bidding_group_total_revenue")

    _total_revenue(
        total_revenue_writer,
        revenue_ex_ante_reader,
        revenue_ex_post_reader,
    )

    return
end
