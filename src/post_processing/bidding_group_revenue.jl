#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function _get_bus_index(bg_bus_combination::String, bus_labels::Vector{String})
    for (i, bus) in enumerate(bus_labels)
        if occursin(bus, bg_bus_combination)
            return i
        end
    end
    return nothing
end

_check_floor(price::Real, floor::Real) = !is_null(floor) ? max(price, floor) : price
_check_cap(price::Real, cap::Real) = !is_null(cap) ? min(price, cap) : price

function _write_revenue_without_subscenarios(
    inputs::Inputs,
    writer_without_subscenarios::Quiver.Writer{Quiver.csv},
    generation_ex_ante_reader::Quiver.Reader{Quiver.csv},
    spot_ex_ante_reader::Quiver.Reader{Quiver.csv},
    is_profile::Bool,
)
    num_periods, num_scenarios, num_subperiods, num_bid_segments =
        generation_ex_ante_reader.metadata.dimension_size

    generation_labels = generation_ex_ante_reader.metadata.labels
    spot_price_labels = spot_ex_ante_reader.metadata.labels
    num_bidding_groups = length(generation_labels)

    dim_name = is_profile ? :profile : :bid_segment

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                sum_generation = zeros(num_bidding_groups)
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

                spot_price_data = zeros(num_bidding_groups)
                for bg_i in 1:num_bidding_groups
                    bus_i = _get_bus_index(generation_labels[bg_i], spot_price_labels)

                    Quiver.goto!(spot_ex_ante_reader; period, scenario, subperiod = subperiod)
                    spot_price_data[bg_i] = spot_ex_ante_reader.data[bus_i]
                end

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
    writer_with_subscenarios::Quiver.Writer{Quiver.csv},
    generation_ex_ante_reader::Union{Quiver.Reader{Quiver.csv}, Nothing},
    generation_ex_post_reader::Quiver.Reader{Quiver.csv},
    spot_ex_ante_reader::Union{Quiver.Reader{Quiver.csv}, Nothing},
    spot_ex_post_reader::Quiver.Reader{Quiver.csv},
    is_profile::Bool,
)
    num_periods, num_scenarios, num_subscenarios, num_subperiods, num_bid_segments =
        generation_ex_post_reader.metadata.dimension_size

    generation_labels = generation_ex_post_reader.metadata.labels
    spot_price_labels = spot_ex_post_reader.metadata.labels
    num_bidding_groups = length(generation_labels)

    dim_name = is_profile ? :profile : :bid_segment

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    sum_generation = zeros(num_bidding_groups)
                    for bid_segment in 1:num_bid_segments
                        Quiver.goto!(
                            generation_ex_post_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                            Symbol(dim_name) => bid_segment,
                        )
                        if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
                            if subscenario == 1
                                # Just read the ex-ante generation once per subscenario
                                Quiver.goto!(
                                    generation_ex_ante_reader;
                                    period,
                                    scenario,
                                    subperiod = subperiod,
                                    Symbol(dim_name) => bid_segment,
                                )
                            end
                            # In the dual settlement, the ex-post generation is the difference between the ex-post and ex-ante generation
                            # The total revenue is the sum of the ex-ante and ex-post revenue
                            sum_generation .+= generation_ex_post_reader.data .- generation_ex_ante_reader.data
                        else
                            sum_generation .+= generation_ex_post_reader.data
                        end
                    end

                    spot_price_data = zeros(num_bidding_groups)
                    for bg_i in 1:num_bidding_groups
                        bus_i = _get_bus_index(generation_labels[bg_i], spot_price_labels)

                        if settlement_type(inputs) == IARA.Configurations_SettlementType.EX_ANTE
                            if subscenario == 1
                                # Just read the ex-ante generation once per subscenario
                                Quiver.goto!(spot_ex_ante_reader; period, scenario, subperiod = subperiod)
                            end
                            spot_price_data[bg_i] = spot_ex_ante_reader.data[bus_i]
                        else
                            Quiver.goto!(
                                spot_ex_post_reader;
                                period,
                                scenario,
                                subscenario = subscenario,
                                subperiod = subperiod,
                            )
                            spot_price_data[bg_i] = spot_ex_post_reader.data[bus_i]
                        end
                    end

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
    if settlement_type(inputs) != IARA.Configurations_SettlementType.EX_POST
        Quiver.close!(generation_ex_ante_reader)
        Quiver.close!(spot_ex_ante_reader)
    end
    Quiver.close!(generation_ex_post_reader)
    Quiver.close!(spot_ex_post_reader)
    return nothing
end

"""
    post_processing_bidding_group_revenue(inputs::Inputs)

Post-process the bidding group revenue data, based on the generation data and the marginal cost data.
"""
function post_processing_bidding_group_revenue(inputs::Inputs)
    outputs_dir = output_path(inputs)

    if settlement_type(inputs) != IARA.Configurations_SettlementType.EX_POST
        bidding_group_generation_ex_ante_files = get_generation_files(outputs_dir; from_ex_post = false)
        bidding_group_load_marginal_cost_ex_ante_files = get_load_marginal_files(outputs_dir; from_ex_post = false)
    end
    bidding_group_generation_ex_post_files = get_generation_files(outputs_dir; from_ex_post = true)
    bidding_group_load_marginal_cost_ex_post_files = get_load_marginal_files(outputs_dir; from_ex_post = true)

    generation_path = outputs_dir
    bidding_group_generation_files = filter(x -> occursin(r"bidding_group_generation_.*\.csv", x), readdir(generation_path))
    if isempty(bidding_group_generation_files)
        generation_path = post_processing_path(inputs)
        bidding_group_generation_files = filter(x -> occursin(r"bidding_group_generation_.*\.csv", x), readdir(generation_path))
    end

    if length(bidding_group_load_marginal_cost_ex_post_files) > 1
        error(
            "Multiple load marginal cost files found: $bidding_group_load_marginal_cost_ex_ante_files",
        )
    end

    if settlement_type(inputs) != IARA.Configurations_SettlementType.EX_POST
        if length(bidding_group_load_marginal_cost_ex_ante_files) > 1
            error(
                "Multiple load marginal cost files found: $bidding_group_load_marginal_cost_ex_ante_files",
            )
        end
    end

    number_of_files = length(bidding_group_generation_ex_post_files)
    output_dir = output_path(inputs)

    for i in 1:number_of_files
        if settlement_type(inputs) != IARA.Configurations_SettlementType.EX_POST
            geneneration_ex_ante_file = get_filename(bidding_group_generation_ex_ante_files[i])
            spot_price_ex_ante_file = get_filename(bidding_group_load_marginal_cost_ex_ante_files[1])
            geneneration_ex_ante_reader =
                Quiver.Reader{Quiver.csv}(joinpath(output_dir, geneneration_ex_ante_file))
            spot_price_ex_ante_reader =
                Quiver.Reader{Quiver.csv}(joinpath(output_dir, spot_price_ex_ante_file))
        else
            geneneration_ex_ante_reader = nothing
            spot_price_ex_ante_reader = nothing
        end
        spot_price_ex_post_file = get_filename(bidding_group_load_marginal_cost_ex_post_files[1])
        geneneration_ex_post_file = get_filename(bidding_group_generation_ex_post_files[i])
        spot_price_ex_post_reader =
            Quiver.Reader{Quiver.csv}(joinpath(output_dir, spot_price_ex_post_file))
        geneneration_ex_post_reader =
            Quiver.Reader{Quiver.csv}(joinpath(output_dir, geneneration_ex_post_file))

        is_cost_based = occursin("cost_based", geneneration_ex_post_file)
        is_profile = occursin("profile", geneneration_ex_post_file)

        time_series_path_with_subscenarios = "bidding_group_revenue"
        time_series_path_without_subscenarios = "bidding_group_revenue"
        file_type_with_subscenarios =
            settlement_type(inputs) == IARA.Configurations_SettlementType.EX_ANTE ? "_ex_ante" : "_ex_post"
        file_type_without_subscenarios = "_ex_ante"

        if is_profile
            time_series_path_with_subscenarios *= "_profile"
            time_series_path_without_subscenarios *= "_profile"
        end

        time_series_path_with_subscenarios *= file_type_with_subscenarios
        time_series_path_without_subscenarios *= file_type_without_subscenarios

        if is_cost_based
            time_series_path_with_subscenarios *= "_cost_based"
            time_series_path_without_subscenarios *= "_cost_based"
        end

        # The revenue is summed over all bid segments / profiles, so we drop the last dimension
        writer_with_subscenarios = Quiver.Writer{Quiver.csv}(
            joinpath(post_processing_path(inputs), time_series_path_with_subscenarios);
            dimensions = String.(geneneration_ex_post_reader.metadata.dimensions[1:end-1]),
            labels = geneneration_ex_post_reader.metadata.labels,
            time_dimension = "period",
            dimension_size = geneneration_ex_post_reader.metadata.dimension_size[1:end-1],
            initial_date = geneneration_ex_post_reader.metadata.initial_date,
            unit = "\$",
        )

        _write_revenue_with_subscenarios(
            inputs,
            writer_with_subscenarios,
            geneneration_ex_ante_reader,
            geneneration_ex_post_reader,
            spot_price_ex_ante_reader,
            spot_price_ex_post_reader,
            is_profile,
        )

        if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
            geneneration_ex_ante_file = get_filename(bidding_group_generation_ex_ante_files[i])
            spot_price_ex_ante_file = get_filename(bidding_group_load_marginal_cost_ex_ante_files[1])
            geneneration_ex_ante_reader =
                Quiver.Reader{Quiver.csv}(joinpath(output_dir, geneneration_ex_ante_file))
            spot_price_ex_ante_reader =
                Quiver.Reader{Quiver.csv}(joinpath(output_dir, spot_price_ex_ante_file))

            writer_without_subscenarios = Quiver.Writer{Quiver.csv}(
                joinpath(post_processing_path(inputs), time_series_path_without_subscenarios);
                dimensions = String.(geneneration_ex_ante_reader.metadata.dimensions[1:end-1]),
                labels = geneneration_ex_ante_reader.metadata.labels,
                time_dimension = "period",
                dimension_size = geneneration_ex_ante_reader.metadata.dimension_size[1:end-1],
                initial_date = geneneration_ex_ante_reader.metadata.initial_date,
                unit = "\$",
            )

            _write_revenue_without_subscenarios(
                inputs,
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

function get_generation_files(outputs_dir::String; from_ex_post::Bool)
    from_ex_post_string = from_ex_post ? "ex_post" : "ex_ante"

    commercial_generation_files = filter(
        x ->
            occursin("bidding_group_generation", x) &&
                occursin(from_ex_post_string * "_commercial", x) &&
                get_file_ext(x) == ".csv",
        readdir(outputs_dir),
    )

    physical_generation_files = filter(
        x ->
            occursin("bidding_group_generation", x) &&
                occursin(from_ex_post_string * "_physical", x) &&
                get_file_ext(x) == ".csv",
        readdir(outputs_dir),
    )

    if isempty(physical_generation_files)
        return commercial_generation_files
    else
        return physical_generation_files
    end
end

function get_load_marginal_files(outputs_dir::String; from_ex_post::Bool)
    from_ex_post_string = from_ex_post ? "ex_post" : "ex_ante"

    commercial_lmc_files = filter(
        x ->
            occursin("load_marginal_cost", x) &&
                occursin(from_ex_post_string * "_commercial", x) && get_file_ext(x) == ".csv", readdir(outputs_dir),
    )

    physical_lmc_files = filter(
        x ->
            occursin("load_marginal_cost", x) &&
                occursin(from_ex_post_string * "_physical", x) && get_file_ext(x) == ".csv", readdir(outputs_dir))

    if isempty(commercial_lmc_files)
        return physical_lmc_files
    else
        return commercial_lmc_files
    end
end

function _average_ex_post_revenue_over_subscenarios(
    temp_writer::Quiver.Writer{Quiver.csv},
    ex_post_reader::Quiver.Reader{Quiver.csv},
)
    num_periods, num_scenarios, num_subscenarios, num_subperiods = ex_post_reader.metadata.dimension_size

    num_bidding_groups = length(ex_post_reader.metadata.labels)

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            summed_vals = zeros(num_subperiods, num_bidding_groups)
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    Quiver.goto!(
                        ex_post_reader;
                        period,
                        scenario,
                        subscenario = subscenario,
                        subperiod = subperiod,
                    )
                    summed_vals[subperiod, :] += ex_post_reader.data
                end
            end
            for subperiod in 1:num_subperiods
                # Average over subscenarios
                Quiver.write!(
                    temp_writer,
                    summed_vals[subperiod, :] ./ num_subscenarios;
                    period,
                    scenario,
                    subperiod = subperiod,
                )
            end
        end
    end
    Quiver.close!(temp_writer)
    return Quiver.close!(ex_post_reader)
end

function _total_independent_profile_ex_ante(
    temp_writer::Quiver.Writer{Quiver.csv},
    independent_reader::Quiver.Reader{Quiver.csv},
    profile_reader::Quiver.Reader{Quiver.csv},
)
    num_periods, num_scenarios, num_subperiods = independent_reader.metadata.dimension_size
    num_bidding_groups = length(independent_reader.metadata.labels)

    merged_labels = unique(vcat(independent_reader.metadata.labels, profile_reader.metadata.labels))

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                Quiver.goto!(
                    profile_reader;
                    period = period,
                    scenario = scenario,
                    subperiod = subperiod,
                )
                Quiver.goto!(
                    independent_reader;
                    period = period,
                    scenario = scenario,
                    subperiod = subperiod,
                )

                bg_indices_independent = Dict{Int, Float64}()
                bg_indices_profile = Dict{Int, Float64}()

                for bg_i in eachindex(merged_labels)
                    bg_label = merged_labels[bg_i]
                    if bg_label in independent_reader.metadata.labels
                        bg_indices_independent[bg_i] =
                            independent_reader.data[findfirst(x -> x == bg_label, independent_reader.metadata.labels)]
                    end
                    if bg_label in profile_reader.metadata.labels
                        bg_indices_profile[bg_i] =
                            profile_reader.data[findfirst(x -> x == bg_label, profile_reader.metadata.labels)]
                    end
                end

                summed_vals = zeros(num_bidding_groups)
                for bg_i in eachindex(merged_labels)
                    summed_vals[bg_i] += get(bg_indices_independent, bg_i, 0) + get(bg_indices_profile, bg_i, 0)
                end

                Quiver.write!(temp_writer, summed_vals; period, scenario, subperiod = subperiod)
            end
        end
    end
    Quiver.close!(temp_writer)
    Quiver.close!(independent_reader)
    Quiver.close!(profile_reader)
    return
end

function _total_independent_profile_ex_post(
    temp_writer::Quiver.Writer{Quiver.csv},
    independent_reader::Quiver.Reader{Quiver.csv},
    profile_reader::Quiver.Reader{Quiver.csv},
)
    num_periods, num_scenarios, num_subscenarios, num_subperiods = independent_reader.metadata.dimension_size
    num_bidding_groups = length(independent_reader.metadata.labels)

    merged_labels = unique(vcat(independent_reader.metadata.labels, profile_reader.metadata.labels))

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    Quiver.goto!(
                        profile_reader;
                        period = period,
                        scenario = scenario,
                        subscenario = subscenario,
                        subperiod = subperiod,
                    )
                    Quiver.goto!(
                        independent_reader;
                        period = period,
                        scenario = scenario,
                        subscenario = subscenario,
                        subperiod = subperiod,
                    )

                    bg_indices_independent = Dict{Int, Float64}()
                    bg_indices_profile = Dict{Int, Float64}()

                    for bg_i in eachindex(merged_labels)
                        bg_label = merged_labels[bg_i]
                        if bg_label in independent_reader.metadata.labels
                            bg_indices_independent[bg_i] =
                                independent_reader.data[findfirst(
                                    x -> x == bg_label,
                                    independent_reader.metadata.labels,
                                )]
                        end
                        if bg_label in profile_reader.metadata.labels
                            bg_indices_profile[bg_i] =
                                profile_reader.data[findfirst(x -> x == bg_label, profile_reader.metadata.labels)]
                        end
                    end

                    summed_vals = zeros(num_bidding_groups)
                    for bg_i in eachindex(merged_labels)
                        summed_vals[bg_i] += get(bg_indices_independent, bg_i, 0) + get(bg_indices_profile, bg_i, 0)
                    end

                    Quiver.write!(
                        temp_writer,
                        summed_vals;
                        period,
                        scenario,
                        subscenario = subscenario,
                        subperiod = subperiod,
                    )
                end
            end
        end
    end
    Quiver.close!(temp_writer)
    Quiver.close!(independent_reader)
    Quiver.close!(profile_reader)
    return
end

function _total_revenue(
    total_revenue_writer::Quiver.Writer{Quiver.csv},
    ex_ante_reader::Quiver.Reader{Quiver.csv},
    ex_post_reader::Quiver.Reader{Quiver.csv},
)
    num_periods, num_scenarios, num_subperiods = ex_ante_reader.metadata.dimension_size

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                Quiver.goto!(ex_ante_reader; period, scenario, subperiod = subperiod)
                Quiver.goto!(ex_post_reader; period, scenario, subperiod = subperiod)

                total_revenue = ex_ante_reader.data .+ ex_post_reader.data

                Quiver.write!(total_revenue_writer, total_revenue; period, scenario, subperiod = subperiod)
            end
        end
    end
    Quiver.close!(total_revenue_writer)
    Quiver.close!(ex_ante_reader)
    Quiver.close!(ex_post_reader)
    return
end

function post_processing_bidding_group_total_revenue(inputs::Inputs)
    post_processing_dir = post_processing_path(inputs)
    outputs_dir = joinpath(output_path(inputs), "post_processing")

    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end

    is_profile =
        length(filter(x -> occursin(r"bidding_group_revenue_profile_.*\.csv", x), readdir(post_processing_dir))) > 0

    is_cost_based =
        length(filter(x -> occursin(r"bidding_group_revenue_.*_cost_based.*\.csv", x), readdir(post_processing_dir))) > 0

    # STEP 0 (optional): Merging profile and independent bid

    if is_profile
        revenue_ex_ante_reader = if !is_cost_based
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante_cost_based"))
        end
        revenue_ex_post_reader = if !is_cost_based
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post_cost_based"))
        end

        revenue_ex_ante_profile_reader =
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante"))
        revenue_ex_post_profile_reader =
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post"))

        merged_labels =
            unique(vcat(revenue_ex_ante_reader.metadata.labels, revenue_ex_ante_profile_reader.metadata.labels))
        temp_revenue_ex_ante_writer = Quiver.Writer{Quiver.csv}(
            joinpath(temp_path, "temp_bidding_group_revenue_ex_ante_total");
            dimensions = String.(revenue_ex_ante_reader.metadata.dimensions),
            labels = merged_labels,
            time_dimension = String(revenue_ex_ante_reader.metadata.time_dimension),
            dimension_size = revenue_ex_ante_reader.metadata.dimension_size,
            initial_date = revenue_ex_ante_reader.metadata.initial_date,
            unit = revenue_ex_ante_reader.metadata.unit,
        )

        temp_revenue_ex_post_writer = Quiver.Writer{Quiver.csv}(
            joinpath(temp_path, "temp_bidding_group_revenue_ex_post_total");
            dimensions = String.(revenue_ex_post_reader.metadata.dimensions),
            labels = merged_labels,
            time_dimension = String(revenue_ex_post_reader.metadata.time_dimension),
            dimension_size = revenue_ex_post_reader.metadata.dimension_size,
            initial_date = revenue_ex_post_reader.metadata.initial_date,
            unit = revenue_ex_post_reader.metadata.unit,
        )

        _total_independent_profile_ex_ante(
            temp_revenue_ex_ante_writer,
            revenue_ex_ante_reader,
            revenue_ex_ante_profile_reader,
        )
        _total_independent_profile_ex_post(
            temp_revenue_ex_post_writer,
            revenue_ex_post_reader,
            revenue_ex_post_profile_reader,
        )
    end

    # STEP 1: Averaging ex_post over subscenarios

    revenue_ex_post_reader = if !is_cost_based
        if is_profile
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_post_total"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post"))
        end
    else
        if is_profile
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_post_total"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post_cost_based"))
        end
    end

    initial_dimension_sizes = copy(revenue_ex_post_reader.metadata.dimension_size)
    revenue_ex_post_average_writer = Quiver.Writer{Quiver.csv}(
        joinpath(temp_path, "temp_bidding_group_revenue_ex_post_average");
        dimensions = ["period", "scenario", "subperiod"],
        labels = revenue_ex_post_reader.metadata.labels,
        time_dimension = String(revenue_ex_post_reader.metadata.time_dimension),
        dimension_size = deleteat!(initial_dimension_sizes, 3), # remove subscenario
        initial_date = revenue_ex_post_reader.metadata.initial_date,
        unit = revenue_ex_post_reader.metadata.unit,
    )

    _average_ex_post_revenue_over_subscenarios(
        revenue_ex_post_average_writer,
        revenue_ex_post_reader,
    )

    # STEP 2: Summing ex_ante and ex_post (ex_ante + mean(ex_post))

    revenue_ex_ante_reader = if !is_cost_based
        if is_profile
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_ante_total"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante"))
        end
    else
        if is_profile
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_ante_total"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante_cost_based"))
        end
    end

    revenue_ex_post_reader =
        Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_post_average"))

    total_revenue_writer = Quiver.Writer{Quiver.csv}(
        joinpath(post_processing_path(inputs), "bidding_group_total_revenue");
        dimensions = String.(revenue_ex_ante_reader.metadata.dimensions),
        labels = revenue_ex_ante_reader.metadata.labels,
        time_dimension = String(revenue_ex_ante_reader.metadata.time_dimension),
        dimension_size = revenue_ex_ante_reader.metadata.dimension_size,
        initial_date = revenue_ex_ante_reader.metadata.initial_date,
        unit = revenue_ex_ante_reader.metadata.unit,
    )

    _total_revenue(
        total_revenue_writer,
        revenue_ex_ante_reader,
        revenue_ex_post_reader,
    )
    return
end
