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

                spot_price_data = zeros(num_bidding_groups_times_buses)
                for bg_i in 1:num_bidding_groups_times_buses
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

                    spot_price_data = zeros(num_bidding_groups_times_buses)
                    for bg_i in 1:num_bidding_groups_times_buses
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

    if settlement_type(inputs) != IARA.Configurations_SettlementType.EX_POST
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

    if settlement_type(inputs) != IARA.Configurations_SettlementType.EX_POST
        if length(bidding_group_load_marginal_cost_ex_ante_files) > 1
            error(
                "Multiple load marginal cost files found: $bidding_group_load_marginal_cost_ex_ante_files",
            )
        end
    end

    number_of_files = length(bidding_group_generation_ex_post_files)
    outputs_dir = output_path(inputs)

    for i in 1:number_of_files
        if settlement_type(inputs) != IARA.Configurations_SettlementType.EX_POST
            geneneration_ex_ante_file = get_filename(bidding_group_generation_ex_ante_files[i])
            spot_price_ex_ante_file = get_filename(bidding_group_load_marginal_cost_ex_ante_files[1])
            geneneration_ex_ante_reader =
                open_time_series_output(inputs, model_outputs_time_serie, geneneration_ex_ante_file)
            spot_price_ex_ante_reader =
                open_time_series_output(inputs, model_outputs_time_serie, spot_price_ex_ante_file)
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
            settlement_type(inputs) == IARA.Configurations_SettlementType.EX_ANTE ? "_ex_ante" : "_ex_post"
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

function _average_ex_post_over_subscenarios(
    temp_writer::Quiver.Writer{Quiver.csv},
    ex_post_reader::Quiver.Reader{Quiver.csv},
)
    num_bidding_groups_times_buses = length(ex_post_reader.metadata.labels)
    num_periods, num_scenarios, num_subscenarios, num_subperiods = ex_post_reader.metadata.dimension_size

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            summed_vals = zeros(num_subperiods, num_bidding_groups_times_buses)
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
    Quiver.close!(ex_post_reader)
    return
end

function _total_independent_profile_without_subscenarios(
    temp_writer::Quiver.Writer{Quiver.csv},
    independent_reader::Union{Quiver.Reader{Quiver.csv}, Nothing},
    profile_reader::Union{Quiver.Reader{Quiver.csv}, Nothing},
    merged_labels::Vector{String},
)
    if isnothing(independent_reader)
        num_periods, num_scenarios, num_subperiods = profile_reader.metadata.dimension_size
    else
        num_periods, num_scenarios, num_subperiods = independent_reader.metadata.dimension_size
    end
    num_bidding_groups = length(merged_labels)

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                if !isnothing(independent_reader)
                    Quiver.goto!(
                        independent_reader;
                        period = period,
                        scenario = scenario,
                        subperiod = subperiod,
                    )
                end
                if !isnothing(profile_reader)
                    Quiver.goto!(
                        profile_reader;
                        period = period,
                        scenario = scenario,
                        subperiod = subperiod,
                    )
                end

                bg_indices_independent = Dict{Int, Float64}()
                bg_indices_profile = Dict{Int, Float64}()

                for bg_i in eachindex(merged_labels)
                    bg_label = merged_labels[bg_i]
                    if !isnothing(independent_reader) && bg_label in independent_reader.metadata.labels
                        bg_indices_independent[bg_i] =
                            independent_reader.data[findfirst(x -> x == bg_label, independent_reader.metadata.labels)]
                    end
                    if !isnothing(profile_reader) && bg_label in profile_reader.metadata.labels
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
    if !isnothing(independent_reader)
        Quiver.close!(independent_reader)
    end
    if !isnothing(profile_reader)
        Quiver.close!(profile_reader)
    end
    return
end

function _total_independent_profile_with_subscenarios(
    temp_writer::Quiver.Writer{Quiver.csv},
    independent_reader::Union{Quiver.Reader{Quiver.csv}, Nothing},
    profile_reader::Union{Quiver.Reader{Quiver.csv}, Nothing},
    merged_labels::Vector{String},
)
    if !isnothing(independent_reader)
        num_periods, num_scenarios, num_subscenarios, num_subperiods = independent_reader.metadata.dimension_size
    else
        num_periods, num_scenarios, num_subscenarios, num_subperiods = profile_reader.metadata.dimension_size
    end
    num_bidding_groups = length(merged_labels)
    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    if !isnothing(independent_reader)
                        Quiver.goto!(
                            independent_reader;
                            period = period,
                            scenario = scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                    end
                    if !isnothing(profile_reader)
                        Quiver.goto!(
                            profile_reader;
                            period = period,
                            scenario = scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                        )
                    end

                    bg_indices_independent = Dict{Int, Float64}()
                    bg_indices_profile = Dict{Int, Float64}()

                    for bg_i in eachindex(merged_labels)
                        bg_label = merged_labels[bg_i]
                        if !isnothing(independent_reader) && bg_label in independent_reader.metadata.labels
                            bg_indices_independent[bg_i] =
                                independent_reader.data[findfirst(
                                    x -> x == bg_label,
                                    independent_reader.metadata.labels,
                                )]
                        end
                        if !isnothing(profile_reader) && bg_label in profile_reader.metadata.labels
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
    if !isnothing(independent_reader)
        Quiver.close!(independent_reader)
    end
    if !isnothing(profile_reader)
        Quiver.close!(profile_reader)
    end
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

function _join_independent_and_profile_bid(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
)
    outputs_dir = output_path(inputs)
    post_processing_dir = post_processing_path(inputs)
    temp_dir = joinpath(path_case(inputs), "temp")

    run_time_file_suffixes(inputs, run_time_options)

    if settlement_type(inputs) != IARA.Configurations_SettlementType.EX_POST
        revenue_ex_ante_independent_reader = open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(post_processing_dir, "bidding_group_revenue_independent_ex_ante"),
        )
        revenue_ex_ante_profile_reader =
            open_time_series_output(
                inputs,
                model_outputs_time_serie,
                joinpath(post_processing_dir, "bidding_group_revenue_profile_ex_ante"),
            )
        if !isnothing(revenue_ex_ante_independent_reader)
            labels_independent = revenue_ex_ante_independent_reader.metadata.labels
        else
            labels_independent = String[]
        end
        if !isnothing(revenue_ex_ante_profile_reader)
            labels_profile = revenue_ex_ante_profile_reader.metadata.labels
        else
            labels_profile = String[]
        end

        merged_labels =
            unique(vcat(labels_independent, labels_profile))

        # If the settlement type is dual, the subscenario dimension is not present in the ex-ante revenue file
        if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
            dimensions = ["period", "scenario", "subperiod"]
        else
            dimensions = ["period", "scenario", "subscenario", "subperiod"]
        end

        initialize!(
            QuiverOutput,
            outputs_post_processing;
            inputs,
            output_name = "bidding_group_revenue_ex_ante",
            dimensions = dimensions,
            unit = "\$",
            labels = merged_labels,
            run_time_options,
            dir_path = post_processing_dir,
        )
        revenue_ex_ante_writer =
            get_writer(outputs_post_processing, inputs, run_time_options, "bidding_group_revenue_ex_ante")

        if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
            _total_independent_profile_without_subscenarios(
                revenue_ex_ante_writer,
                revenue_ex_ante_independent_reader,
                revenue_ex_ante_profile_reader,
                merged_labels,
            )
        else
            _total_independent_profile_with_subscenarios(
                revenue_ex_ante_writer,
                revenue_ex_ante_independent_reader,
                revenue_ex_ante_profile_reader,
                merged_labels,
            )
        end
    end
    if settlement_type(inputs) != IARA.Configurations_SettlementType.EX_ANTE
        revenue_ex_post_indepedent_reader = open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(post_processing_dir, "bidding_group_revenue_independent_ex_post"),
        )
        revenue_ex_post_profile_reader =
            open_time_series_output(
                inputs,
                model_outputs_time_serie,
                joinpath(post_processing_dir, "bidding_group_revenue_profile_ex_post"),
            )

        if !isnothing(revenue_ex_post_indepedent_reader)
            labels_independent = revenue_ex_post_indepedent_reader.metadata.labels
        else
            labels_independent = String[]
        end
        if !isnothing(revenue_ex_post_profile_reader)
            labels_profile = revenue_ex_post_profile_reader.metadata.labels
        else
            labels_profile = String[]
        end

        merged_labels =
            unique(vcat(labels_independent, labels_profile))

        initialize!(
            QuiverOutput,
            outputs_post_processing;
            inputs,
            output_name = "bidding_group_revenue_ex_post",
            dimensions = ["period", "scenario", "subscenario", "subperiod"],
            unit = "\$",
            labels = merged_labels,
            run_time_options,
            dir_path = post_processing_dir,
        )
        revenue_ex_post_writer =
            get_writer(outputs_post_processing, inputs, run_time_options, "bidding_group_revenue_ex_post")

        _total_independent_profile_with_subscenarios(
            revenue_ex_post_writer,
            revenue_ex_post_indepedent_reader,
            revenue_ex_post_profile_reader,
            merged_labels,
        )
    end

    return nothing
end

function average_ex_post_revenue(
    inputs::Inputs,
    outputs_post_processing::Outputs,
    model_outputs_time_serie::OutputReaders,
    run_time_options::RunTimeOptions,
)
    post_processing_dir = post_processing_path(inputs)
    temp_dir = joinpath(path_case(inputs), "temp")

    revenue_ex_post_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(
            post_processing_dir,
            "bidding_group_revenue_ex_post" * run_time_file_suffixes(inputs, run_time_options),
        ),
    )

    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = "temp_bidding_group_revenue_ex_post_average",
        dimensions = ["period", "scenario", "subperiod"],
        unit = "\$",
        labels = revenue_ex_post_reader.metadata.labels,
        run_time_options,
        dir_path = temp_dir,
    )
    revenue_ex_post_average_writer =
        get_writer(
            outputs_post_processing,
            inputs,
            run_time_options,
            "temp_bidding_group_revenue_ex_post_average",
        )

    _average_ex_post_over_subscenarios(
        revenue_ex_post_average_writer,
        revenue_ex_post_reader,
    )

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

    # Summing ex_ante and ex_post (ex_ante + mean(ex_post))

    revenue_ex_ante_reader = open_time_series_output(
        inputs,
        model_outputs_time_serie,
        joinpath(post_processing_dir, "bidding_group_revenue_ex_ante"),
    )

    revenue_ex_post_reader =
        open_time_series_output(
            inputs,
            model_outputs_time_serie,
            joinpath(tempdir, "temp_bidding_group_revenue_ex_post_average"),
        )

    initialize!(
        QuiverOutput,
        outputs_post_processing;
        inputs,
        output_name = "bidding_group_total_revenue",
        dimensions = ["period", "scenario", "subperiod"],
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
