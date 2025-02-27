function get_offer_file_paths(inputs::AbstractInputs)
    offer_files = String[]
    if is_market_clearing(inputs) && any_elements(inputs, BiddingGroup)
        if read_bids_from_file(inputs)
            push!(offer_files, joinpath(path_case(inputs), bidding_group_quantity_offer_file(inputs) * ".csv"))
            push!(offer_files, joinpath(path_case(inputs), bidding_group_price_offer_file(inputs) * ".csv"))
        elseif generate_heuristic_bids_for_clearing(inputs)
            push!(
                offer_files,
                joinpath(output_path(inputs), "bidding_group_energy_offer_period_$(inputs.args.period).csv"),
            )
            push!(
                offer_files,
                joinpath(output_path(inputs), "bidding_group_price_offer_period_$(inputs.args.period).csv"),
            )
        end
        @assert all(isfile.(offer_files)) "Offer files not found: $(offer_files)"
        no_markup_price_folder = if read_bids_from_file(inputs)
            path_case(inputs)
        else
            output_path(inputs)
        end
        no_markup_price_path =
            joinpath(no_markup_price_folder, "bidding_group_no_markup_price_offer_period_$(inputs.args.period).csv")
        if isfile(no_markup_price_path)
            push!(offer_files, no_markup_price_path)
        else
            @warn("Reference price (no markup) offer file not found: $(no_markup_price_path)")
        end
    end

    return offer_files
end

function plot_title_from_filename(inputs::AbstractInputs, filename::String)
    title = replace(filename, "_period_$(inputs.args.period)" => "")
    title = _snake_to_regular(title)
    title = replace(title, "Ex Post" => "Ex-Post")
    title = replace(title, "Ex Ante" => "Ex-Ante")
    return title
end

function get_revenue_files(inputs::AbstractInputs)
    filenames = if settlement_type(inputs) == IARA.Configurations_SettlementType.EX_ANTE
        ["bidding_group_revenue_ex_ante"]
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.EX_POST
        ["bidding_group_revenue_ex_post"]
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        ["bidding_group_revenue_ex_ante", "bidding_group_revenue_ex_post"]
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.NONE
        [""]
    end
    filenames .*= "_period_$(inputs.args.period)"
    filenames .*= ".csv"

    return joinpath.(post_processing_path(inputs), filenames)
end

function get_profit_file(inputs::AbstractInputs)
    filename = if settlement_type(inputs) == IARA.Configurations_SettlementType.EX_ANTE
        "bidding_group_profit_ex_ante"
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.EX_POST
        "bidding_group_profit_ex_post"
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        "bidding_group_profit_total"
    elseif settlement_type(inputs) == IARA.Configurations_SettlementType.NONE
        ""
    end
    filename *= "_period_$(inputs.args.period)"
    filename *= ".csv"

    return joinpath(post_processing_path(inputs), filename)
end

function get_load_marginal_cost_files(inputs::AbstractInputs)
    base_name = "load_marginal_cost"
    period_suffix = "_period_$(inputs.args.period)"
    extension = ".csv"

    filenames = String[]

    if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        ex_ante_suffixes = ["_ex_ante_commercial", "_ex_ante_physical"]
        ex_post_suffixes = ["_ex_post_commercial", "_ex_post_physical"]

        for subproblem_suffix in ex_ante_suffixes
            filename = base_name * subproblem_suffix * period_suffix * extension
            if isfile(joinpath(output_path(inputs), filename))
                push!(filenames, joinpath(output_path(inputs), filename))
                break
            end
        end

        for subproblem_suffix in ex_post_suffixes
            filename = base_name * subproblem_suffix * period_suffix * extension
            if isfile(joinpath(output_path(inputs), filename))
                push!(filenames, joinpath(output_path(inputs), filename))
                break
            end
        end
    else
        subproblem_suffixes = ["_ex_post_commercial", "_ex_post_physical", "_ex_ante_commercial", "_ex_ante_physical"]

        for subproblem_suffix in subproblem_suffixes
            filename = base_name * subproblem_suffix * period_suffix * extension
            if isfile(joinpath(output_path(inputs), filename))
                push!(filenames, joinpath(output_path(inputs), filename))
                break
            end
        end
    end

    if isempty(filenames)
        error("Load marginal cost file not found")
    end

    return filenames
end

function get_generation_files(inputs::AbstractInputs)
    base_name = "bidding_group_generation"
    period_suffix = "_period_$(inputs.args.period)"
    extension = ".csv"

    filenames = String[]

    if settlement_type(inputs) == IARA.Configurations_SettlementType.DUAL
        ex_ante_suffixes = ["_ex_ante_physical", "_ex_ante_commercial"]
        ex_post_suffixes = ["_ex_post_physical", "_ex_post_commercial"]

        for subproblem_suffix in ex_ante_suffixes
            filename = base_name * subproblem_suffix * period_suffix * extension
            if isfile(joinpath(output_path(inputs), filename))
                push!(filenames, joinpath(output_path(inputs), filename))
                break
            elseif isfile(joinpath(post_processing_path(inputs), filename))
                push!(filenames, joinpath(post_processing_path(inputs), filename))
                break
            end
        end

        for subproblem_suffix in ex_post_suffixes
            filename = base_name * subproblem_suffix * period_suffix * extension
            if isfile(joinpath(output_path(inputs), filename))
                push!(filenames, joinpath(output_path(inputs), filename))
                break
            elseif isfile(joinpath(post_processing_path(inputs), filename))
                push!(filenames, joinpath(post_processing_path(inputs), filename))
                break
            end
        end
    else
        subproblem_suffixes = ["_ex_post_physical", "_ex_post_commercial", "_ex_ante_physical", "_ex_ante_commercial"]

        for subproblem_suffix in subproblem_suffixes
            filename = base_name * subproblem_suffix * period_suffix * extension
            if isfile(joinpath(output_path(inputs), filename))
                push!(filenames, joinpath(output_path(inputs), filename))
                break
            elseif isfile(joinpath(post_processing_path(inputs), filename))
                push!(filenames, joinpath(post_processing_path(inputs), filename))
                break
            end
        end
    end

    if isempty(filenames)
        error("Generation file not found")
    end

    return filenames
end

function get_demands_to_plot(
    inputs::AbstractInputs,
)
    number_of_demands = number_of_elements(inputs, DemandUnit)
    # TODO: filter out demands that belong to a bidding group

    ex_ante_demand = ones(number_of_periods(inputs) * number_of_subperiods(inputs))
    if read_ex_ante_demand_file(inputs)
        demand_file = joinpath(path_case(inputs), demand_unit_demand_ex_ante_file(inputs) * ".csv")
        data, metadata = read_timeseries_file(demand_file)
        num_periods, num_scenarios, num_subperiods = metadata.dimension_size
        data = merge_period_subperiod(data)

        ex_ante_demand = zeros(num_periods * num_subperiods)
        # Use only first scenario
        scenario = 1
        for d in 1:number_of_demands
            ex_ante_demand += data[d, scenario, :] * demand_unit_max_demand(inputs, d)
        end
        if num_scenarios > 1
            @warn "Plotting demand for scenario 1 and ignoring the other scenarios. Total number of scenarios in file $demand_file: $num_scenarios"
        end
    end

    ex_post_min_demand = copy(ex_ante_demand)
    ex_post_max_demand = copy(ex_ante_demand)
    if read_ex_post_demand_file(inputs)
        demand_file = joinpath(path_case(inputs), demand_unit_demand_ex_post_file(inputs) * ".csv")
        data, metadata = read_timeseries_file(demand_file)
        num_periods, num_scenarios, num_subscenarios, num_subperiods = metadata.dimension_size
        data = merge_period_subperiod(data)

        ex_post_demand = zeros(num_subscenarios, num_periods * num_subperiods)
        # Use only first scenario
        scenario = 1
        for d in 1:number_of_demands
            ex_post_demand += data[d, :, scenario, :] * demand_unit_max_demand(inputs, d)
        end
        if num_scenarios > 1
            @warn "Plotting demand for scenario 1 and ignoring the other scenarios. Total number of scenarios in file $demand_file: $num_scenarios"
        end

        # Min and max demand across subscenarios
        ex_post_min_demand = dropdims(minimum(ex_post_demand, dims = 1), dims = 1)
        ex_post_max_demand = dropdims(maximum(ex_post_demand, dims = 1), dims = 1)

        # If there is no ex-ante demand file, the ex-ante demand is the average of the ex-post demand across subscenarios
        if !read_ex_ante_demand_file(inputs)
            ex_ante_demand = dropdims(mean(ex_post_demand, dims = 1), dims = 1)
        end
    end

    return ex_ante_demand, ex_post_min_demand, ex_post_max_demand
end
