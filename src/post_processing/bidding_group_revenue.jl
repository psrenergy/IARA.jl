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

function _write_revenue_ex_ante(
    writer::Quiver.Writer{Quiver.csv},
    generation_reader::Quiver.Reader{Quiver.csv},
    spot_reader::Quiver.Reader{Quiver.csv},
    spot_price_cap::Real,
    spot_price_floor::Real,
    is_profile::Bool,
)
    # used for ex_ante_commercial, ex_ante_physical

    num_periods, num_scenarios, num_subperiods, num_bid_segments = generation_reader.metadata.dimension_size
    num_bidding_groups = length(generation_reader.metadata.labels)
    dim_name = is_profile ? :profile : :bid_segment
    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                Quiver.goto!(spot_reader; period, scenario, subperiod = subperiod)
                sum_generation = zeros(num_bidding_groups)
                for bid_segment in 1:num_bid_segments
                    Quiver.goto!(
                        generation_reader;
                        period,
                        scenario,
                        subperiod = subperiod,
                        Symbol(dim_name) => bid_segment,
                    )
                    sum_generation .+= generation_reader.data
                end

                revenue = zeros(num_bidding_groups)
                for bg in 1:num_bidding_groups
                    bus_i = _get_bus_index(generation_reader.metadata.labels[bg], spot_reader.metadata.labels)

                    raw_load_marginal_cost = _check_floor(spot_reader.data[bus_i], spot_price_floor)
                    raw_load_marginal_cost = _check_cap(raw_load_marginal_cost, spot_price_cap)
                    
                    revenue[bg] = sum_generation[bg] * raw_load_marginal_cost / MW_to_GW() # GWh to MWh
                end
                Quiver.write!(
                    writer,
                    revenue;
                    period,
                    scenario,
                    subperiod = subperiod,
                )
            end
        end
    end
    Quiver.close!(writer)
    Quiver.close!(generation_reader)
    Quiver.close!(spot_reader)
    return
end

function _write_revenue_ex_post(
    writer::Quiver.Writer{Quiver.csv},
    generation_reader::Quiver.Reader{Quiver.csv},
    spot_reader::Quiver.Reader{Quiver.csv},
    spot_price_cap::Real,
    spot_price_floor::Real,
    is_profile::Bool,
)
    # used for ex_post_commercial, ex_post_physical

    num_periods, num_scenarios, num_subscenarios, num_subperiods, num_bid_segments =
        generation_reader.metadata.dimension_size
    num_bidding_groups = length(generation_reader.metadata.labels)

    dim_name = is_profile ? :profile : :bid_segment

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    Quiver.goto!(spot_reader; period, scenario, subscenario = subscenario, subperiod = subperiod)
                    sum_generation = zeros(num_bidding_groups)
                    for bid_segment in 1:num_bid_segments
                        Quiver.goto!(
                            generation_reader;
                            period,
                            scenario,
                            subscenario = subscenario,
                            subperiod = subperiod,
                            Symbol(dim_name) => bid_segment,
                        )
                        sum_generation .+= generation_reader.data
                    end

                    revenue = zeros(num_bidding_groups)
                    for bg in 1:num_bidding_groups
                        bus_i = _get_bus_index(generation_reader.metadata.labels[bg], spot_reader.metadata.labels)

                        raw_load_marginal_cost = _check_floor(spot_reader.data[bus_i], spot_price_floor)
                        raw_load_marginal_cost = _check_cap(raw_load_marginal_cost, spot_price_cap)

                        revenue[bg] = sum_generation[bg] * raw_load_marginal_cost / MW_to_GW() # GWh to MWh
                    end
                    Quiver.write!(
                        writer,
                        revenue;
                        period,
                        scenario,
                        subscenario,
                        subperiod = subperiod,
                    )
                end
            end
        end
    end
    Quiver.close!(writer)
    Quiver.close!(generation_reader)
    Quiver.close!(spot_reader)
    return
end

"""
    post_processing_bidding_group_revenue(inputs::Inputs)

Post-process the bidding group revenue data, based on the generation data and the marginal cost data.
"""
function post_processing_bidding_group_revenue(inputs::Inputs)
    outputs_dir = output_path(inputs)

    spot_price_cap = inputs.collections.configurations.spot_price_cap
    spot_price_floor = inputs.collections.configurations.spot_price_floor

    generation_path = outputs_dir
    bidding_group_generation_files = filter(x -> occursin(r"bidding_group_generation_.*\.csv", x), readdir(generation_path))
    if isempty(bidding_group_generation_files)
        generation_path = post_processing_path(inputs)
        bidding_group_generation_files = filter(x -> occursin(r"bidding_group_generation_.*\.csv", x), readdir(generation_path))
    end

    for file in bidding_group_generation_files
        is_cost_based = occursin(r"_cost_based", file)

        m = match(r"^bidding_group_generation(_profile){0,1}(_ex_[a-z]+_[a-z]+)(?:_cost_based){0,1}(_period){0,1}([0-9]*).*\.csv$", file)
        file_type = m[2]
        is_profile = !isnothing(m[1])

        file_end = "load_marginal_cost$file_type"
        if is_single_period(inputs)
            file_end *= "_period_$(inputs.args.period)"
        end
        file_end *= ".csv"
        load_marginal_cost_file = filter(x -> startswith(x, file_end), readdir(outputs_dir))
        if isempty(load_marginal_cost_file)
            return
        end

        generation_reader = Quiver.Reader{Quiver.csv}(joinpath(generation_path, split(file, ".")[1]))
        spot_reader = Quiver.Reader{Quiver.csv}(joinpath(outputs_dir, split(load_marginal_cost_file[1], ".")[1]))

        time_series_path = "bidding_group_revenue"
        if isnothing(m[1])
            time_series_path *= file_type
        else
            time_series_path *= m[1] * file_type
        end
        if is_cost_based
            time_series_path *= "_cost_based"
        end

        # The revenue is summed over all bid segments / profiles, so we drop the last dimension
        writer = Quiver.Writer{Quiver.csv}(
            joinpath(post_processing_path(inputs), time_series_path);
            dimensions = String.(generation_reader.metadata.dimensions[1:end-1]),
            labels = generation_reader.metadata.labels,
            time_dimension = "period",
            dimension_size = generation_reader.metadata.dimension_size[1:end-1],
            initial_date = generation_reader.metadata.initial_date,
            unit = "\$",
        )

        if startswith(file_type, "_ex_post")
            _write_revenue_ex_post(
                writer,
                generation_reader,
                spot_reader,
                spot_price_cap,
                spot_price_floor,
                is_profile,
            )
        else
            _write_revenue_ex_ante(
                writer,
                generation_reader,
                spot_reader,
                spot_price_cap,
                spot_price_floor,
                is_profile,
            )
        end
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
    post_processing_dir = post_processing_path(inputs)

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
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_ante_$(type)"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_ante_$(type)_cost_based"))
        end
        revenue_ex_post_reader = if !is_cost_based
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_post_$(type)"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_post_$(type)_cost_based"))
        end

        revenue_ex_ante_profile_reader =
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_ante_$(type)"))
        revenue_ex_post_profile_reader =
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_post_$(type)"))

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
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_post_$(type)"))
        end
    else
        if is_profile
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_post_$(type)_sum"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_post_$(type)_cost_based"))
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
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_ante_$(type)"))
        end
    else
        if is_profile
            Quiver.Reader{Quiver.csv}(joinpath(temp_path, "temp_bidding_group_revenue_ex_ante_$(type)_sum"))
        else
            Quiver.Reader{Quiver.csv}(joinpath(post_processing_dir, "bidding_group_revenue_ex_ante_$(type)_cost_based"))
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
    if !isfile(joinpath(post_processing_path(inputs), "bidding_group_revenue_ex_ante_commercial.csv"))
        return
    end

    return _bidding_group_total_revenue(inputs, "commercial")
end
