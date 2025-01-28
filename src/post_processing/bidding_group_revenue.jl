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

function _build_revenue_without_subscenarios(
    inputs::Inputs,
    generation_ex_ante::Array{<:AbstractFloat, 5},
    spot_ex_ante::Array{<:AbstractFloat, 4},
    generation_labels::Vector{String},
    spot_price_labels::Vector{String},
)
    spot_price_cap = inputs.collections.configurations.spot_price_cap
    spot_price_floor = inputs.collections.configurations.spot_price_floor

    num_bidding_groups = number_of_elements(inputs, BiddingGroup)
    num_buses = number_of_elements(inputs, Bus)

    num_bgs_times_buses, num_bid_segments, num_subperiods, num_scenarios, num_periods = 
    size(generation_ex_ante)
    
    revenue = zeros(num_bidding_groups, num_subperiods, num_scenarios, num_periods)

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                sum_generation = zeros(num_bgs_times_buses)
                for bid_segment in 1:num_bid_segments
                    generation_data = generation_ex_ante[:, bid_segment, subperiod, scenario, period]
                    sum_generation .+= generation_data
                end

                for bg_i in 1:num_bidding_groups
                    bus_i = _get_bus_index(generation_labels[bg_i], spot_price_labels)

                    spot_price_data = spot_ex_ante[bus_i, subperiod, scenario, period]
                    processed_load_marginal_cost = _check_floor(spot_price_data, spot_price_floor)
                    processed_load_marginal_cost = _check_cap(processed_load_marginal_cost, spot_price_cap)

                    revenue[bg_i, subperiod, scenario, period] = sum_generation[(bg_i - 1) * (num_buses) + bus_i] * processed_load_marginal_cost / MW_to_GW()
                end
            end
        end
    end
    return revenue
end

function _build_revenue_with_subscenarios(
    inputs::Inputs,
    generation_ex_ante::Array{<:AbstractFloat, 5},
    generation_ex_post::Array{<:AbstractFloat, 6},
    spot_ex_ante::Array{<:AbstractFloat, 4},
    spot_ex_post::Array{<:AbstractFloat, 5},
    generation_labels::Vector{String},
    spot_price_labels::Vector{String},
)
    spot_price_cap = inputs.collections.configurations.spot_price_cap
    spot_price_floor = inputs.collections.configurations.spot_price_floor

    num_bidding_groups = number_of_elements(inputs, BiddingGroup)
    num_buses = number_of_elements(inputs, Bus)
    num_bgs_times_buses, num_bid_segments, num_subperiods, num_subscenarios, num_scenarios, num_periods =
    size(generation_ex_post)

    revenue = zeros(num_bidding_groups, num_subperiods, num_subscenarios, num_scenarios, num_periods)

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    sum_generation = zeros(num_bgs_times_buses)
                    for bid_segment in 1:num_bid_segments
                        generation_ex_ante_data = generation_ex_ante[:, bid_segment, subperiod, scenario, period]
                        generation_ex_post_data = generation_ex_post[:, bid_segment, subperiod, subscenario, scenario, period]
                        if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
                            # In the dual settlement, the ex-post generation is the difference between the ex-post and ex-ante generation
                            # The total revenue is the sum of the ex-ante and ex-post revenue
                            sum_generation .+= generation_ex_post_data .- generation_ex_ante_data
                        else
                            sum_generation .+= generation_ex_post_data
                        end
                    end

                    for bg_i in 1:num_bidding_groups
                        bus_i = _get_bus_index(generation_labels[bg_i], spot_price_labels)
                        
                        if settlement_type(inputs) == IARA.Configurations_SettlementType.EX_ANTE
                            spot_price_data = spot_ex_ante[bus_i, subperiod, scenario, period]
                        else
                            spot_price_data = spot_ex_post[bus_i, subperiod, subscenario, scenario, period]
                        end

                        processed_load_marginal_cost = _check_floor(spot_price_data, spot_price_floor)
                        processed_load_marginal_cost = _check_cap(processed_load_marginal_cost, spot_price_cap)

                        revenue[bg_i, subperiod, subscenario, scenario, period] += sum_generation[(bg_i - 1) * (num_buses) + bus_i] * processed_load_marginal_cost / MW_to_GW()
                    end
                end
            end
        end
    end
    return revenue
end

"""
    post_processing_bidding_group_revenue(inputs::Inputs)

Post-process the bidding group revenue data, based on the generation data and the marginal cost data.
"""
function post_processing_bidding_group_revenue(inputs::Inputs)
    outputs_dir = output_path(inputs)

    bidding_group_generation_ex_ante_files = get_generation_files(outputs_dir; from_ex_post = false)
    bidding_group_load_marginal_cost_ex_ante_files = get_load_marginal_files(outputs_dir; from_ex_post = false)
    bidding_group_generation_ex_post_files = get_generation_files(outputs_dir; from_ex_post = true)
    bidding_group_load_marginal_cost_ex_post_files = get_load_marginal_files(outputs_dir; from_ex_post = true)
    
    if length(bidding_group_load_marginal_cost_ex_post_files) > 1 || length(bidding_group_load_marginal_cost_ex_ante_files) > 1
        error("Multiple load marginal cost files found: $bidding_group_load_marginal_cost_ex_post_files, $bidding_group_load_marginal_cost_ex_ante_files")
    end
    
    spot_price_ex_ante_data, metadata_spot_price_ex_ante = read_timeseries_file_in_outputs(get_filename(bidding_group_load_marginal_cost_ex_ante_files[1]), inputs)
    spot_price_ex_post_data, metadata_spot_price_ex_post = read_timeseries_file_in_outputs(get_filename(bidding_group_load_marginal_cost_ex_post_files[1]), inputs)

    number_of_files = length(bidding_group_generation_ex_ante_files)

    for i in 1:number_of_files
        geneneration_file_ex_ante = get_filename(bidding_group_generation_ex_ante_files[i])
        geneneration_file_ex_post = get_filename(bidding_group_generation_ex_post_files[i])
        geneneration_ex_ante_data, metadata_geneneration_ex_ante = read_timeseries_file_in_outputs(geneneration_file_ex_ante, inputs)
        geneneration_ex_post_data, metadata_geneneration_ex_post = read_timeseries_file_in_outputs(geneneration_file_ex_post, inputs)

        is_cost_based = occursin("cost_based", geneneration_file_ex_post)
        is_profile = occursin("profile", geneneration_file_ex_post)

        time_series_path_with_subscenarios = "bidding_group_revenue"
        time_series_path_without_subscenarios = "bidding_group_revenue"
        file_type_with_subscenarios = settlement_type(inputs) == IARA.Configurations_SettlementType.EX_ANTE ? "_ex_ante" : "_ex_post"
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

        revenue_with_subscenarios = _build_revenue_with_subscenarios(
            inputs,
            geneneration_ex_ante_data,
            geneneration_ex_post_data,
            spot_price_ex_ante_data,
            spot_price_ex_post_data,
            metadata_geneneration_ex_post.labels,
            metadata_spot_price_ex_post.labels,
        )

            
        # The revenue is summed over all bid segments / profiles, so we drop the last dimension
        write_timeseries_file(
            joinpath(post_processing_path(inputs), time_series_path_with_subscenarios),
            revenue_with_subscenarios;
            dimensions = String.(metadata_geneneration_ex_post.dimensions[1:end-1]),
            labels = metadata_geneneration_ex_post.labels,
            time_dimension = "period",
            dimension_size = metadata_geneneration_ex_post.dimension_size[1:end-1],
            initial_date = metadata_geneneration_ex_post.initial_date,
            unit = "\$",
        )

        if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL

            revenue_without_subscenarios = _build_revenue_without_subscenarios(
                inputs,
                geneneration_ex_ante_data,
                spot_price_ex_ante_data,
                metadata_geneneration_ex_ante.labels,
                metadata_spot_price_ex_ante.labels,
            )

            write_timeseries_file(
                joinpath(post_processing_path(inputs), time_series_path_without_subscenarios),
                revenue_without_subscenarios;
                dimensions = String.(metadata_geneneration_ex_ante.dimensions[1:end-1]),
                labels = metadata_geneneration_ex_ante.labels,
                time_dimension = "period",
                dimension_size = metadata_geneneration_ex_ante.dimension_size[1:end-1],
                initial_date = metadata_geneneration_ex_ante.initial_date,
                unit = "\$",
            )
        end
    end
    return
end

function get_generation_files(outputs_dir::String; from_ex_post::Bool)
    from_ex_post_string = from_ex_post ? "ex_post" : "ex_ante"
    return filter(
        x -> 
        occursin("bidding_group_generation", x) && 
        occursin(from_ex_post_string * "_physical", x) &&
        get_file_ext(x) == ".csv",
        readdir(outputs_dir)
    )
end

function get_load_marginal_files(outputs_dir::String; from_ex_post::Bool)
    from_ex_post_string = from_ex_post ? "ex_post" : "ex_ante"
    
    commercial_lmc_files = filter(x -> occursin("load_marginal_cost", x) && 
        occursin(from_ex_post_string * "_commercial", x) && get_file_ext(x) == ".csv", readdir(outputs_dir))

    physical_lmc_files = filter(x -> occursin("load_marginal_cost", x) && 
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

function _sum_independent_profile_ex_ante(
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

function _sum_independent_profile_ex_post(
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

function _sum_total_revenue(
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

function _bidding_group_total_revenue(inputs::Inputs, type::String)
    outputs_dir = output_path(inputs)

    temp_path = joinpath(path_case(inputs), "temp")
    if !isdir(temp_path)
        mkdir(temp_path)
    end

    is_profile =
        length(filter(x -> occursin(r"bidding_group_revenue_profile_.*\.csv", x), readdir(outputs_dir))) > 0

    is_cost_based =
        length(filter(x -> occursin(r"bidding_group_revenue_.*_cost_based\.csv", x), readdir(outputs_dir))) > 0

    # STEP 0 (optional): Merging profile and independent bid

    if is_profile
        revenue_ex_ante_reader = if !is_cost_based
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante_$(type)"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante_$(type)_cost_based"))
        end
        revenue_ex_post_reader = if !is_cost_based
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post_$(type)"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post_$(type)_cost_based"))
        end

        revenue_ex_ante_profile_reader =
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante_$(type)"))
        revenue_ex_post_profile_reader =
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post_$(type)"))

        merged_labels =
            unique(vcat(revenue_ex_ante_reader.metadata.labels, revenue_ex_ante_profile_reader.metadata.labels))
        temp_revenue_ex_ante_writer = Quiver.Writer{Quiver.csv}(
            joinpath(temp_path, "temp_bidding_group_revenue_ex_ante_$(type)_sum");
            dimensions = String.(revenue_ex_ante_reader.metadata.dimensions),
            labels = merged_labels,
            time_dimension = String(revenue_ex_ante_reader.metadata.time_dimension),
            dimension_size = revenue_ex_ante_reader.metadata.dimension_size,
            initial_date = revenue_ex_ante_reader.metadata.initial_date,
            unit = revenue_ex_ante_reader.metadata.unit,
        )

        temp_revenue_ex_post_writer = Quiver.Writer{Quiver.csv}(
            joinpath(temp_path, "temp_bidding_group_revenue_ex_post_$(type)_sum");
            dimensions = String.(revenue_ex_post_reader.metadata.dimensions),
            labels = merged_labels,
            time_dimension = String(revenue_ex_post_reader.metadata.time_dimension),
            dimension_size = revenue_ex_post_reader.metadata.dimension_size,
            initial_date = revenue_ex_post_reader.metadata.initial_date,
            unit = revenue_ex_post_reader.metadata.unit,
        )

        _sum_independent_profile_ex_ante(
            temp_revenue_ex_ante_writer,
            revenue_ex_ante_reader,
            revenue_ex_ante_profile_reader,
        )
        _sum_independent_profile_ex_post(
            temp_revenue_ex_post_writer,
            revenue_ex_post_reader,
            revenue_ex_post_profile_reader,
        )
    end

    # STEP 1: Averaging ex_post over subscenarios

    revenue_ex_post_reader = if !is_cost_based
        if is_profile
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_post_$(type)_sum"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post_$(type)"))
        end
    else
        if is_profile
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_post_$(type)_sum"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_post_$(type)_cost_based"))
        end
    end

    initial_dimension_sizes = copy(revenue_ex_post_reader.metadata.dimension_size)
    revenue_ex_post_average_writer = Quiver.Writer{Quiver.csv}(
        joinpath(temp_path, "temp_bidding_group_revenue_ex_post_$(type)_average");
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
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_ante_$(type)_sum"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante_$(type)"))
        end
    else
        if is_profile
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_ante_$(type)_sum"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, "bidding_group_revenue_ex_ante_$(type)_cost_based"))
        end
    end

    revenue_ex_post_reader =
        Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_post_$(type)_average"))

    total_revenue_writer = Quiver.Writer{Quiver.csv}(
        joinpath(post_processing_path(inputs), "bidding_group_total_revenue_$(type)");
        dimensions = String.(revenue_ex_ante_reader.metadata.dimensions),
        labels = revenue_ex_ante_reader.metadata.labels,
        time_dimension = String(revenue_ex_ante_reader.metadata.time_dimension),
        dimension_size = revenue_ex_ante_reader.metadata.dimension_size,
        initial_date = revenue_ex_ante_reader.metadata.initial_date,
        unit = revenue_ex_ante_reader.metadata.unit,
    )

    _sum_total_revenue(
        total_revenue_writer,
        revenue_ex_ante_reader,
        revenue_ex_post_reader,
    )
    return
end

function post_processing_bidding_group_total_revenue(inputs::Inputs)
    outputs_dir = output_path(inputs)

    if !isfile(joinpath(outputs_dir, "bidding_group_revenue_ex_ante_commercial.csv"))
        return
    end

    return _bidding_group_total_revenue(inputs, "commercial")
end
