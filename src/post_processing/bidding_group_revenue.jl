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
    get_spot_prices(spot_price_data, bus_collection, generation_labels, network_representation)

Get spot prices for all bidding groups based on the network representation.

# Arguments
- `spot_price_data`: Spot price data for the current period/scenario/subperiod, indexed by bus or zone
- `bus_collection`: The bus collection with zone indices and labels
- `generation_labels`: Array of generation labels in format "bg_X - bus_Y"
- `network_representation`: The network representation type (ZONAL or NODAL)

# Returns
- Vector of spot prices corresponding to each generation label
"""
function get_spot_prices(spot_price_data, bus_collection, generation_labels, network_representation)
    # Pre-allocate array for spot prices
    spot_prices = similar(spot_price_data, length(generation_labels))

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
        spot_prices[i] = spot_price_data[location_idx]
    end

    return spot_prices
end

# Helper functions for price bounds
_check_floor(price::Real, floor::Real) = !is_null(floor) ? max(price, floor) : price
_check_cap(price::Real, cap::Real) = !is_null(cap) ? min(price, cap) : price

function _write_revenue_without_subscenarios(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    writer_without_subscenarios::Quiver.Binary.File,
    generation_ex_ante_reader::Quiver.Binary.File,
    spot_ex_ante_reader::Quiver.Binary.File,
    is_profile::Bool,
)
    generation_md = Quiver.Binary.get_metadata(generation_ex_ante_reader)
    num_periods, num_scenarios, num_subperiods, num_bid_segments =
        metadata_dimension_sizes(generation_md)

    generation_labels = Quiver.Binary.get_labels(generation_md)
    num_bidding_groups_times_buses = length(generation_labels)

    dim_name = is_profile ? :profile : :bid_segment

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                sum_generation = zeros(num_bidding_groups_times_buses)
                for bid_segment in 1:num_bid_segments
                    generation_data = Quiver.Binary.read(
                        generation_ex_ante_reader;
                        allow_nulls = true,
                        period,
                        scenario,
                        subperiod = subperiod,
                        Symbol(dim_name) => bid_segment,
                    )
                    sum_generation .+= generation_data
                end

                # Read spot prices for the current period/scenario/subperiod
                spot_data = Quiver.Binary.read(
                    spot_ex_ante_reader;
                    allow_nulls = true,
                    period,
                    scenario,
                    subperiod = subperiod,
                )

                # Get network representation type once
                net_rep = network_representation_ex_ante_commercial(inputs)

                # Get spot prices for all bidding groups based on network representation
                spot_price_data = get_spot_prices(
                    spot_data,
                    inputs.collections.bus,
                    generation_labels,
                    net_rep,
                )

                Quiver.Binary.write!(
                    writer_without_subscenarios;
                    data = sum_generation .* apply_lmc_bounds(spot_price_data, inputs) / MW_to_GW(), # GWh to MWh
                    period,
                    scenario,
                    subperiod = subperiod,
                )
            end
        end
    end
    finalize_writer!(writer_without_subscenarios)
    # Close readers because they reached the end of the file.
    Quiver.Binary.close!(generation_ex_ante_reader)
    Quiver.Binary.close!(spot_ex_ante_reader)
    return nothing
end

function _write_revenue_with_subscenarios(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    writer_with_subscenarios::Quiver.Binary.File,
    generation_ex_ante_reader::Union{Quiver.Binary.File, Nothing},
    generation_ex_post_reader::Quiver.Binary.File,
    spot_ex_ante_reader::Union{Quiver.Binary.File, Nothing},
    spot_ex_post_reader::Quiver.Binary.File,
    is_profile::Bool,
)
    generation_md = Quiver.Binary.get_metadata(generation_ex_post_reader)
    num_periods, num_scenarios, num_subscenarios, num_subperiods, num_bid_segments =
        metadata_dimension_sizes(generation_md)

    generation_labels = Quiver.Binary.get_labels(generation_md)
    num_bidding_groups_times_buses = length(generation_labels)

    dim_name = is_profile ? :profile : :bid_segment

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    sum_generation = zeros(num_bidding_groups_times_buses)
                    for bid_segment in 1:num_bid_segments
                        generation_ex_post_data = Quiver.Binary.read(
                            generation_ex_post_reader;
                            allow_nulls = true,
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                            Symbol(dim_name) => bid_segment,
                        )
                        if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
                            # Just read the ex-ante generation once per subscenario
                            generation_ex_ante_data = Quiver.Binary.read(
                                generation_ex_ante_reader;
                                allow_nulls = true,
                                period,
                                scenario,
                                subperiod = subperiod,
                                Symbol(dim_name) => bid_segment,
                            )
                            # In the double settlement, the ex-post generation is the difference between the ex-post and ex-ante generation
                            # The total revenue is the sum of the ex-ante and ex-post revenue
                            sum_generation .+= generation_ex_post_data .- generation_ex_ante_data
                        else
                            sum_generation .+= generation_ex_post_data
                        end
                    end

                    # Select the appropriate reader based on settlement type
                    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE
                        spot_data = Quiver.Binary.read(
                            spot_ex_ante_reader;
                            allow_nulls = true,
                            period,
                            scenario,
                            subperiod = subperiod,
                        )
                        net_rep = network_representation_ex_ante_commercial(inputs)
                    else
                        spot_data = Quiver.Binary.read(
                            spot_ex_post_reader;
                            allow_nulls = true,
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                        net_rep = network_representation_ex_post_commercial(inputs)
                    end

                    # Get spot prices for all bidding groups based on network representation
                    spot_price_data = get_spot_prices(
                        spot_data,
                        inputs.collections.bus,
                        generation_labels,
                        net_rep,
                    )

                    Quiver.Binary.write!(
                        writer_with_subscenarios;
                        data = sum_generation .* apply_lmc_bounds(spot_price_data, inputs) / MW_to_GW(), # GWh to MWh
                        period,
                        scenario,
                        subscenario,
                        subperiod = subperiod,
                    )
                end
            end
        end
    end
    finalize_writer!(writer_with_subscenarios)
    # Close readers because they reached the end of the file.
    if settlement_type(inputs) != IARA.Configurations_FinancialSettlementType.EX_POST
        Quiver.Binary.close!(generation_ex_ante_reader)
        Quiver.Binary.close!(spot_ex_ante_reader)
    end
    Quiver.Binary.close!(generation_ex_post_reader)
    Quiver.Binary.close!(spot_ex_post_reader)
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
    outputs_dir = output_path(inputs, run_time_options)
    post_processing_dir = post_processing_path(inputs, run_time_options)

    if settlement_type(inputs) != IARA.Configurations_FinancialSettlementType.EX_POST
        bidding_group_generation_ex_ante_files =
            get_generation_files(outputs_dir, post_processing_path(inputs, run_time_options); from_ex_post = false)
        bidding_group_load_marginal_cost_ex_ante_files = get_load_marginal_files(outputs_dir; from_ex_post = false)
    end
    bidding_group_generation_ex_post_files =
        get_generation_files(outputs_dir, post_processing_path(inputs, run_time_options); from_ex_post = true)
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
    outputs_dir = output_path(inputs, run_time_options)

    for i in 1:number_of_files
        if settlement_type(inputs) != IARA.Configurations_FinancialSettlementType.EX_POST
            geneneration_ex_ante_file = get_filename(bidding_group_generation_ex_ante_files[i])
            spot_price_ex_ante_file = get_filename(bidding_group_load_marginal_cost_ex_ante_files[1])
            geneneration_ex_ante_reader =
                open_time_series_output(
                    inputs,
                    model_outputs_time_serie,
                    geneneration_ex_ante_file,
                )
            spot_price_ex_ante_reader =
                open_time_series_output(
                    inputs,
                    model_outputs_time_serie,
                    spot_price_ex_ante_file,
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
            labels = Quiver.Binary.get_labels(Quiver.Binary.get_metadata(geneneration_ex_post_reader)),
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
                labels = Quiver.Binary.get_labels(Quiver.Binary.get_metadata(geneneration_ex_ante_reader)),
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
    total_revenue_writer::Quiver.Binary.File,
    ex_ante_reader::Quiver.Binary.File,
    ex_post_reader::Quiver.Binary.File,
)
    num_periods, num_scenarios, num_subscenarios, num_subperiods =
        metadata_dimension_sizes(Quiver.Binary.get_metadata(ex_post_reader))

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    ex_ante_data =
                        Quiver.Binary.read(ex_ante_reader; allow_nulls = true, period, scenario, subperiod = subperiod)
                    ex_post_data = Quiver.Binary.read(
                        ex_post_reader;
                        allow_nulls = true,
                        period,
                        scenario,
                        subscenario = subscenario,
                        subperiod = subperiod,
                    )

                    total_revenue = ex_ante_data .+ ex_post_data

                    Quiver.Binary.write!(
                        total_revenue_writer;
                        data = total_revenue,
                        period,
                        scenario,
                        subscenario = subscenario,
                        subperiod = subperiod,
                    )
                end
            end
        end
    end
    finalize_writer!(total_revenue_writer)
    Quiver.Binary.close!(ex_ante_reader)
    Quiver.Binary.close!(ex_post_reader)
    return
end

function _join_independent_and_profile_bid(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
)
    post_processing_dir = post_processing_path(inputs, run_time_options)
    temp_dir = joinpath(output_path(inputs, run_time_options), "temp")
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
                "\$";
                has_subscenarios = has_subscenarios,
            )
        end

        file_revenue_ex_ante = joinpath(
            post_processing_dir,
            "bidding_group_revenue_ex_ante" * run_time_file_suffixes(inputs, run_time_options),
        )

        reader_independent = Quiver.Binary.open_file(filepath_independent; mode = 'r')
        reader_profile = Quiver.Binary.open_file(filepath_profile; mode = 'r')
        Quiver.save(reader_independent + reader_profile, file_revenue_ex_ante)
        Quiver.Binary.bin_to_csv(file_revenue_ex_ante; aggregate_time_dimensions = false)
        Quiver.Binary.close!(reader_independent)
        Quiver.Binary.close!(reader_profile)
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
                "\$";
                has_subscenarios = true,
            )
        end

        file_revenue_ex_post = joinpath(
            post_processing_dir,
            "bidding_group_revenue_ex_post" * run_time_file_suffixes(inputs, run_time_options),
        )

        reader_independent = Quiver.Binary.open_file(filepath_independent; mode = 'r')
        reader_profile = Quiver.Binary.open_file(filepath_profile; mode = 'r')
        Quiver.save(reader_independent + reader_profile, file_revenue_ex_post)
        Quiver.Binary.bin_to_csv(file_revenue_ex_post; aggregate_time_dimensions = false)
        Quiver.Binary.close!(reader_independent)
        Quiver.Binary.close!(reader_profile)
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
    outputs_dir = output_path(inputs, run_time_options)
    post_processing_dir = post_processing_path(inputs, run_time_options)
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
        joinpath(post_processing_dir, "bidding_group_revenue_ex_ante" * period_suffix),
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
        labels = Quiver.Binary.get_labels(Quiver.Binary.get_metadata(revenue_ex_ante_reader)),
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
