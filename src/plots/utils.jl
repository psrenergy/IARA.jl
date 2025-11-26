function get_bidding_group_bid_file_paths(inputs::AbstractInputs)
    bid_files = String[]
    if is_market_clearing(inputs) && any_elements(inputs, BiddingGroup)
        if read_bids_from_file(inputs)
            push!(bid_files, joinpath(path_case(inputs), bidding_group_quantity_bid_file(inputs) * ".csv"))
            push!(bid_files, joinpath(path_case(inputs), bidding_group_price_bid_file(inputs) * ".csv"))
        elseif generate_heuristic_bids_for_clearing(inputs)
            push!(
                bid_files,
                joinpath(output_path(inputs), "bidding_group_energy_bid_period_$(inputs.args.period).csv"),
            )
            push!(
                bid_files,
                joinpath(output_path(inputs), "bidding_group_price_bid_period_$(inputs.args.period).csv"),
            )
        end
        @assert all(isfile.(bid_files)) "Offer files not found: $(bid_files)"
        no_markup_price_folder = if read_bids_from_file(inputs)
            path_case(inputs)
        else
            output_path(inputs)
        end
        no_markup_price_path =
            joinpath(no_markup_price_folder, "bidding_group_no_markup_price_bid_period_$(inputs.args.period).csv")
        no_markup_quantity_path =
            joinpath(no_markup_price_folder, "bidding_group_no_markup_energy_bid_period_$(inputs.args.period).csv")
        if isfile(no_markup_price_path) && isfile(no_markup_quantity_path)
            push!(bid_files, no_markup_price_path)
            push!(bid_files, no_markup_quantity_path)
        else
            @warn(
                "Reference price and quantity bid files not found: $(no_markup_price_path), $(no_markup_quantity_path)"
            )
        end
    end

    return bid_files
end

function get_virtual_reservoir_bid_file_paths(inputs::AbstractInputs)
    bid_files = String[]
    if is_market_clearing(inputs) && any_elements(inputs, VirtualReservoir)
        if read_bids_from_file(inputs)
            push!(bid_files, joinpath(path_case(inputs), virtual_reservoir_quantity_bid_file(inputs) * ".csv"))
            push!(bid_files, joinpath(path_case(inputs), virtual_reservoir_price_bid_file(inputs) * ".csv"))
        elseif generate_heuristic_bids_for_clearing(inputs)
            push!(
                bid_files,
                joinpath(output_path(inputs), "virtual_reservoir_energy_bid_period_$(inputs.args.period).csv"),
            )
            push!(
                bid_files,
                joinpath(output_path(inputs), "virtual_reservoir_price_bid_period_$(inputs.args.period).csv"),
            )
        end
        @assert all(isfile.(bid_files)) "Offer files not found: $(bid_files)"
        no_markup_price_folder = if read_bids_from_file(inputs)
            path_case(inputs)
        else
            output_path(inputs)
        end
        no_markup_price_path =
            joinpath(no_markup_price_folder, "virtual_reservoir_no_markup_price_bid_period_$(inputs.args.period).csv")
        no_markup_quantity_path =
            joinpath(no_markup_price_folder, "virtual_reservoir_no_markup_energy_bid_period_$(inputs.args.period).csv")
        if isfile(no_markup_price_path) && isfile(no_markup_quantity_path)
            push!(bid_files, no_markup_price_path)
            push!(bid_files, no_markup_quantity_path)
        else
            @warn(
                "Reference price and quantity bid files not found: $(no_markup_price_path), $(no_markup_quantity_path)"
            )
        end
    end

    return bid_files
end

function plot_title_from_filename(inputs::AbstractInputs, filename::String)
    title = replace(filename, "_period_$(inputs.args.period)" => "")
    title = _snake_to_regular(title)
    title = replace(title, "Ex Post" => "Ex-Post")
    title = replace(title, "Ex Ante" => "Ex-Ante")
    return title
end

function get_revenue_files(inputs::AbstractInputs)
    filenames = if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE
        ["bidding_group_revenue_ex_ante"]
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_POST
        ["bidding_group_revenue_ex_post"]
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
        ["bidding_group_revenue_ex_ante", "bidding_group_revenue_ex_post"]
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.NONE
        [""]
    end
    filenames .*= "_period_$(inputs.args.period)"
    filenames .*= ".csv"

    return joinpath.(post_processing_path(inputs), filenames)
end

function get_virtual_reservoir_revenue_files(inputs::AbstractInputs)
    filenames = if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE
        ["virtual_reservoir_total_revenue_ex_ante"]
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_POST
        ["virtual_reservoir_total_revenue_ex_post"]
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
        ["virtual_reservoir_total_revenue_ex_ante", "virtual_reservoir_total_revenue_ex_post"]
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.NONE
        [""]
    end
    filenames .*= "_period_$(inputs.args.period)"
    filenames .*= ".csv"

    return joinpath.(post_processing_path(inputs), filenames)
end

function get_profit_file(inputs::AbstractInputs)
    filename = if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE
        "bidding_group_profit_ex_ante"
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_POST
        "bidding_group_profit_ex_post"
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
        "bidding_group_profit_total"
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.NONE
        ""
    end
    filename *= "_period_$(inputs.args.period)"
    filename *= ".csv"

    return joinpath(post_processing_path(inputs), filename)
end

function get_virtual_reservoir_profit_file(inputs::AbstractInputs)
    # For the virtual reservoirs, the profit files are the same as the revenue files
    filename = if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_ANTE
        "virtual_reservoir_total_revenue_ex_ante"
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.EX_POST
        "virtual_reservoir_total_revenue_ex_post"
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
        "virtual_reservoir_total_revenue"
    elseif settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.NONE
        ""
    end
    if occursin("_ex_", filename)
        filename *= "_period_$(inputs.args.period)"
    end
    filename *= ".csv"

    return joinpath(post_processing_path(inputs), filename)
end

function get_virtual_reservoir_generation_files(inputs::AbstractInputs)
    base_name = "virtual_reservoir_generation"
    period_suffix = "_period_$(inputs.args.period)"
    extension = ".csv"

    filenames = String[]

    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
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
        error("Virtual reservoir generation file not found")
    end

    return filenames
end

function get_variable_cost_file(inputs::AbstractInputs)
    base_name = "bidding_group_variable_costs"
    period_suffix = "_period_$(inputs.args.period)"
    extension = ".csv"

    subproblem_suffixes = ["_ex_post_physical", "_ex_post_commercial", "_ex_ante_physical", "_ex_ante_commercial"]
    filename = ""

    for subproblem_suffix in subproblem_suffixes
        filename = base_name * subproblem_suffix * period_suffix * extension
        if isfile(joinpath(output_path(inputs), filename))
            break
        elseif isfile(joinpath(post_processing_path(inputs), filename))
            break
        end
        if subproblem_suffix == last(subproblem_suffixes)
            error("Cost file not found")
        end
    end

    return joinpath(post_processing_path(inputs), filename)
end

function get_load_marginal_cost_files(inputs::AbstractInputs)
    base_name = "load_marginal_cost"
    period_suffix = "_period_$(inputs.args.period)"
    extension = ".csv"

    filenames = String[]

    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
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

    if settlement_type(inputs) == IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT
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

    num_subscenarios_placeholder = 1
    ex_post_demand = zeros(num_subscenarios_placeholder, number_of_periods(inputs) * number_of_subperiods(inputs))
    ex_post_demand[num_subscenarios_placeholder, :] = copy(ex_ante_demand)
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

        # If there is no ex-ante demand file, the ex-ante demand is the average of the ex-post demand across subscenarios
        if !read_ex_ante_demand_file(inputs)
            ex_ante_demand = dropdims(mean(ex_post_demand; dims = 1); dims = 1)
        end
    end

    return ex_ante_demand, ex_post_demand
end

function get_renewable_generation_to_plot(
    inputs::AbstractInputs;
    asset_owner_index::Int = null_value(Int),
    @nospecialize(filters::Vector{<:Function} = Function[])
)
    if is_null(asset_owner_index)
        renewable_units = index_of_elements(inputs, RenewableUnit; filters)
    else
        bidding_groups = filter(
            bg -> bidding_group_asset_owner_index(inputs, bg) == asset_owner_index,
            index_of_elements(inputs, BiddingGroup),
        )
        renewable_units = filter(
            r -> any(renewable_unit_bidding_group_index(inputs, r) .== bidding_groups),
            index_of_elements(inputs, RenewableUnit),
        )
        if isempty(renewable_units)
            return [], []
        end
    end

    ex_ante_generation = ones(number_of_periods(inputs) * number_of_subperiods(inputs))
    if read_ex_ante_renewable_file(inputs)
        generation_file = joinpath(path_case(inputs), renewable_unit_generation_ex_ante_file(inputs) * ".csv")
        data, metadata = read_timeseries_file(generation_file)
        num_periods, num_scenarios, num_subperiods = metadata.dimension_size
        data = merge_period_subperiod(data)

        ex_ante_generation = zeros(num_periods * num_subperiods)
        # Use only first scenario
        scenario = 1
        for r in renewable_units
            ex_ante_generation += data[r, scenario, :] * renewable_unit_max_generation(inputs, r)
        end
        if num_scenarios > 1
            @warn "Plotting renewable generation for scenario 1 and ignoring the other scenarios. Total number of scenarios in file $generation_file: $num_scenarios"
        end
    end

    num_subscenarios_placeholder = 1
    ex_post_generation = zeros(num_subscenarios_placeholder, number_of_periods(inputs) * number_of_subperiods(inputs))
    ex_post_generation[num_subscenarios_placeholder, :] = copy(ex_ante_generation)
    if read_ex_post_renewable_file(inputs)
        generation_file = joinpath(path_case(inputs), renewable_unit_generation_ex_post_file(inputs) * ".csv")
        data, metadata = read_timeseries_file(generation_file)
        num_periods, num_scenarios, num_subscenarios, num_subperiods = metadata.dimension_size
        data = merge_period_subperiod(data)

        ex_post_generation = zeros(num_subscenarios, num_periods * num_subperiods)
        # Use only first scenario
        scenario = 1
        for r in renewable_units
            ex_post_generation += data[r, :, scenario, :] * renewable_unit_max_generation(inputs, r)
        end
        if num_scenarios > 1
            @warn "Plotting renewable generation for scenario 1 and ignoring the other scenarios. Total number of scenarios in file $generation_file: $num_scenarios"
        end

        # If there is no ex-ante renewable generation file, the ex-ante renewable generation is the average of the ex-post renewable generation across subscenarios
        if !read_ex_ante_renewable_file(inputs)
            ex_ante_generation = dropdims(mean(ex_post_generation; dims = 1); dims = 1)
        end
    end

    return ex_ante_generation, ex_post_generation
end

function get_inflow_energy_to_plot(
    inputs::AbstractInputs;
    asset_owner_index::Int,
    virtual_reservoir_index::Int,
)
    num_periods = number_of_periods(inputs)
    num_subperiods = number_of_subperiods(inputs)

    # Check if this asset owner is part of this virtual reservoir
    vr_asset_owners = virtual_reservoir_asset_owner_indices(inputs, virtual_reservoir_index)
    if !(asset_owner_index in vr_asset_owners)
        return [], []
    end

    # Get inflow allocation factor for this asset owner in this virtual reservoir
    inflow_allocation =
        virtual_reservoir_asset_owners_inflow_allocation(inputs, virtual_reservoir_index, asset_owner_index)

    # Initialize hydro unit volumes (using initial volumes as a simplification for plotting)
    volume_at_beginning_of_period = zeros(number_of_elements(inputs, HydroUnit))
    for h in index_of_elements(inputs, HydroUnit)
        volume_at_beginning_of_period[h] = hydro_unit_initial_volume(inputs, h)
    end

    # Ex-ante inflow energy calculation
    ex_ante_inflow_energy = zeros(num_periods * num_subperiods)
    if read_ex_ante_inflow_file(inputs)
        # Process inflow data period by period
        run_time_options = RunTimeOptions()
        for period in 1:num_periods
            update_time_series_views_from_external_files!(inputs, run_time_options; period, scenario = 1)
            inflow_series = time_series_inflow(inputs, run_time_options)
            vr_energy_arrival = energy_from_inflows(inputs, inflow_series, volume_at_beginning_of_period)

            # Distribute energy evenly across subperiods for this period
            for subperiod in 1:num_subperiods
                idx = (period - 1) * num_subperiods + subperiod
                ex_ante_inflow_energy[idx] =
                    vr_energy_arrival[virtual_reservoir_index] * inflow_allocation / num_subperiods
            end
        end
    end

    # Ex-post inflow energy calculation
    num_subscenarios = 1
    if read_ex_post_inflow_file(inputs)
        # Determine number of subscenarios from the ex-post data
        if isdefined(inputs.time_series.inflow.ex_post, :data)
            num_subscenarios = size(inputs.time_series.inflow.ex_post.data, 3)
        end
    end

    ex_post_inflow_energy = zeros(num_subscenarios, num_periods * num_subperiods)

    if read_ex_post_inflow_file(inputs)
        run_time_options_ex_post =
            RunTimeOptions(; clearing_model_subproblem = RunTime_ClearingSubproblem.EX_POST_PHYSICAL)
        for subscenario in 1:num_subscenarios
            for period in 1:num_periods
                update_time_series_views_from_external_files!(inputs, run_time_options_ex_post; period, scenario = 1)
                inflow_series = time_series_inflow(inputs, run_time_options_ex_post; subscenario = subscenario)
                vr_energy_arrival = energy_from_inflows(inputs, inflow_series, volume_at_beginning_of_period)

                # Distribute energy evenly across subperiods
                for subperiod in 1:num_subperiods
                    idx = (period - 1) * num_subperiods + subperiod
                    ex_post_inflow_energy[subscenario, idx] =
                        vr_energy_arrival[virtual_reservoir_index] * inflow_allocation / num_subperiods
                end
            end
        end

        # If there is no ex-ante inflow file, use average of ex-post
        if !read_ex_ante_inflow_file(inputs)
            ex_ante_inflow_energy = dropdims(mean(ex_post_inflow_energy; dims = 1); dims = 1)
        end
    else
        # If no ex-post data, use ex-ante for ex-post
        ex_post_inflow_energy[1, :] = copy(ex_ante_inflow_energy)
    end

    return ex_ante_inflow_energy, ex_post_inflow_energy
end

function convert_generation_data_from_GWh_to_MW!(
    data::Array{T, N},
    metadata::Quiver.Metadata,
    inputs::AbstractInputs,
) where {T, N}
    if metadata.unit == "MW"
        @error("Data is already in MW")
    end
    @assert metadata.unit == "GWh" "Unit conversion only implemented for GWh"

    if N == 5
        @assert metadata.dimensions == [:period, :scenario, :subscenario, :subperiod]
        num_subperiods = metadata.dimension_size[4]
        for subperiod in 1:num_subperiods
            data[:, subperiod, :, :, :] .*= 1000 / subperiod_duration_in_hours(inputs, subperiod)
        end
    elseif N == 4
        if metadata.dimensions == [:period, :scenario, :subscenario]
            # Virtual reservoir data without subperiods - convert using period duration
            # Assuming the energy is for the entire period, convert using total period duration
            total_period_hours = sum(subperiod_duration_in_hours(inputs, sp) for sp in 1:number_of_subperiods(inputs))
            data .*= 1000 / total_period_hours
        elseif metadata.dimensions == [:period, :scenario, :subperiod]
            num_subperiods = metadata.dimension_size[3]
            for subperiod in 1:num_subperiods
                data[:, subperiod, :, :] .*= 1000 / subperiod_duration_in_hours(inputs, subperiod)
            end
        else
            @error("Unit conversion not implemented for dimensions $(metadata.dimensions)")
        end
    elseif N == 3
        @assert metadata.dimensions == [:period, :scenario] "Unit conversion not implemented for dimensions $(metadata.dimensions)"
        # Virtual reservoir data without subperiods or subscenarios - convert using period duration
        total_period_hours = sum(subperiod_duration_in_hours(inputs, sp) for sp in 1:number_of_subperiods(inputs))
        data .*= 1000 / total_period_hours
    else
        @error("Unit conversion not implemented for data with $(N) dimensions")
    end

    metadata.unit = "MW"

    return data
end

function title_font_size()
    # Plotly default is 17
    return 17
end

function legend_font_size()
    # Plotly default is 12
    return 14
end

function axis_title_font_size()
    # Plotly default is 14
    return 14
end

function axis_tick_font_size()
    # Plotly default is 12
    return 12
end

function format_data_to_plot(
    inputs::AbstractInputs,
    file_path::String;
    asset_owner_index::Union{Int, Nothing} = nothing,
    aggregate_header_by_asset_owner::Bool = true,
)
    data, metadata = read_timeseries_file(file_path)

    if :bid_segment in metadata.dimensions
        segment_index = findfirst(isequal(:bid_segment), metadata.dimensions)
        # The data array has dimensions in reverse order, and the first dimension is metadata.number_of_time_series, which is not in metadata.dimensions
        segment_index_in_data = length(metadata.dimensions) + 2 - segment_index
        data = dropdims(sum(data; dims = segment_index_in_data); dims = segment_index_in_data)
        metadata.dimension_size = metadata.dimension_size[1:end.!=segment_index]
        metadata.dimensions = metadata.dimensions[1:end.!=segment_index]
    end

    if occursin("generation", basename(file_path))
        convert_generation_data_from_GWh_to_MW!(data, metadata, inputs)
    end

    is_virtual_reservoir_file = occursin("virtual_reservoir", basename(file_path))

    has_subscenarios = :subscenario in metadata.dimensions
    has_subperiods = :subperiod in metadata.dimensions

    if has_subscenarios
        if has_subperiods
            @assert metadata.dimensions == [:period, :scenario, :subscenario, :subperiod] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
            num_periods, num_scenarios, num_subscenarios, num_subperiods = metadata.dimension_size
            reshaped_data = data[:, :, :, 1, 1]
        else
            @assert metadata.dimensions == [:period, :scenario, :subscenario] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
            num_periods, num_scenarios, num_subscenarios = metadata.dimension_size
            num_subperiods = 1
            reshaped_data = Array{Float64, 3}(undef, metadata.number_of_time_series, num_subperiods, num_subscenarios)
            reshaped_data[:, 1, :] = data[:, :, 1]
        end
    else
        num_subscenarios = 1
        if has_subperiods
            @assert metadata.dimensions == [:period, :scenario, :subperiod] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
            num_periods, num_scenarios, num_subperiods = metadata.dimension_size
            reshaped_data = Array{Float64, 3}(undef, metadata.number_of_time_series, num_subperiods, num_subscenarios)
            reshaped_data[:, :, 1] = data[:, :, 1, 1]
        else
            @assert metadata.dimensions == [:period, :scenario] "Invalid dimensions $(metadata.dimensions) for time series file $(file_path)"
            num_periods, num_scenarios = metadata.dimension_size
            num_subperiods = 1
            reshaped_data = Array{Float64, 3}(undef, metadata.number_of_time_series, num_subperiods, num_subscenarios)
            reshaped_data[:, 1, 1] = data[:, 1, 1]
        end
    end

    if num_scenarios > 1 &&
       (isnothing(asset_owner_index) || asset_owner_index == first(index_of_elements(inputs, AssetOwner)))
        @warn "Plotting asset owner $title for scenario 1 and ignoring the other scenarios. Total number of scenarios: $num_scenarios"
    end
    @assert num_periods == 1 "$title plot only implemented for single period run mode. Number of periods: $num_periods"

    if aggregate_header_by_asset_owner
        reshaped_data = aggregate_data_header(
            inputs,
            reshaped_data,
            metadata;
            asset_owner_index,
            is_virtual_reservoir_file,
        )
    end

    return reshaped_data, metadata, num_subperiods, num_subscenarios
end

function aggregate_data_header(
    inputs::AbstractInputs,
    data::Array{T, 3},
    metadata::Quiver.Metadata;
    asset_owner_index::Union{Int, Nothing} = nothing,
    is_virtual_reservoir_file::Bool,
) where {T <: Real}
    num_subperiods, num_subscenarios = size(data, 2), size(data, 3)

    if isnothing(asset_owner_index)
        asset_owner_indexes = index_of_elements(inputs, AssetOwner)
        reshaped_data = Array{Float64, 3}(undef, length(asset_owner_indexes), num_subperiods, num_subscenarios)
        for (i, asset_owner_index) in enumerate(asset_owner_indexes)
            labels_to_read = if is_virtual_reservoir_file
                vr_ao_labels_for_asset_owner(inputs, asset_owner_index)
            else
                bg_bus_labels_for_asset_owner(inputs, asset_owner_index)
            end
            indexes_to_read = [findfirst(isequal(label), metadata.labels) for label in labels_to_read]
            reshaped_data[i, :, :] = dropdims(sum(data[indexes_to_read, :, :]; dims = 1); dims = 1)
        end
    else
        reshaped_data = Array{Float64, 2}(undef, num_subperiods, num_subscenarios)
        labels_to_read = if is_virtual_reservoir_file
            vr_ao_labels_for_asset_owner(inputs, asset_owner_index)
        else
            bg_bus_labels_for_asset_owner(inputs, asset_owner_index)
        end
        indexes_to_read = [findfirst(isequal(label), metadata.labels) for label in labels_to_read]
        reshaped_data = dropdims(sum(data[indexes_to_read, :, :]; dims = 1); dims = 1)
    end

    return reshaped_data
end

function bg_bus_labels_for_asset_owner(
    inputs::AbstractInputs,
    asset_owner_index::Int,
)
    labels_to_read = String[]
    bidding_group_indexes =
        index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    for bg in bidding_group_indexes
        if bidding_group_asset_owner_index(inputs, bg) != asset_owner_index
            continue
        end
        bg_label = bidding_group_label(inputs, bg)
        for bus in bus_label(inputs)
            push!(labels_to_read, "$bg_label - $bus")
        end
    end
    return labels_to_read
end

function vr_ao_labels_for_asset_owner(
    inputs::AbstractInputs,
    asset_owner_index::Int,
)
    labels_to_read = String[]
    virtual_reservoir_indexes = index_of_elements(inputs, VirtualReservoir)
    for vr in virtual_reservoir_indexes
        if !(asset_owner_index in virtual_reservoir_asset_owner_indices(inputs, vr))
            continue
        end
        vr_label = virtual_reservoir_label(inputs, vr)
        ao_label = asset_owner_label(inputs, asset_owner_index)
        push!(labels_to_read, "$vr_label - $ao_label")
    end
    return labels_to_read
end
