function nash_bids_from_hydro_reference_curve(
    inputs::AbstractInputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    period::Int = 1,
    scenario::Int = 1,
)
    vr_original_quantity_bid, vr_original_price_bid =
        read_serialized_virtual_reservoir_heuristic_bids(inputs; period, scenario)

    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
    number_of_virtual_reservoirs = length(virtual_reservoirs)
    number_of_asset_owners = number_of_elements(inputs, AssetOwner)

    vr_quantity_output = zeros(
        Float64,
        number_of_virtual_reservoirs,
        number_of_asset_owners,
        reference_curve_nash_max_iterations(inputs),
        maximum_number_of_segments_in_nash_equilibrium(inputs),
    )
    vr_price_output = zeros(
        Float64,
        number_of_virtual_reservoirs,
        number_of_asset_owners,
        reference_curve_nash_max_iterations(inputs),
        maximum_number_of_segments_in_nash_equilibrium(inputs),
    )
    vr_slope_output = fill(
        Inf,
        number_of_virtual_reservoirs,
        number_of_asset_owners,
        reference_curve_nash_max_iterations(inputs),
        maximum_number_of_segments_in_nash_equilibrium(inputs),
    )

    for vr in virtual_reservoirs
        asset_owners_in_virtual_reservoir = virtual_reservoir_asset_owner_indices(inputs, vr)
        number_of_asset_owners_in_virtual_reservoir = length(asset_owners_in_virtual_reservoir)
        q, p, b = treat_reference_curve_data(
            inputs,
            vr_original_quantity_bid,
            vr_original_price_bid,
            vr,
        )
        original_q = deepcopy(q)
        original_p = deepcopy(p)
        original_b = deepcopy(b)
        for iter in 1:reference_curve_nash_max_iterations(inputs)
            q, p, b = run_reference_curve_nash_iteration(
                inputs,
                number_of_asset_owners_in_virtual_reservoir;
                current_quantity = q,
                current_price = p,
                current_slope = b,
                original_quantity = original_q,
                original_price = original_p,
                original_slope = original_b,
            )
            for (i, ao) in enumerate(virtual_reservoir_asset_owner_indices(inputs, vr))
                number_of_segments = length(q[i])
                vr_quantity_output[vr, ao, iter, 1:number_of_segments] = q[i]
                vr_price_output[vr, ao, iter, 1:number_of_segments] = p[i]
                vr_slope_output[vr, ao, iter, 1:number_of_segments] = b[i]
            end
        end
    end

    write_reference_curve_nash_vr_outputs(
        inputs,
        outputs,
        run_time_options,
        vr_quantity_output,
        vr_price_output,
        vr_slope_output,
        period,
        scenario,
    )

    if !any_elements(inputs, BiddingGroup) || !has_any_simple_bids(inputs)
        return nothing
    end

    bg_original_quantity_bid, bg_original_price_bid = read_serialized_heuristic_bids(inputs; period, scenario)

    buses = index_of_elements(inputs, Bus)
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    number_of_buses = length(buses)
    number_of_bidding_groups = length(bidding_groups)

    bg_quantity_output = zeros(
        Float64,
        number_of_bidding_groups,
        number_of_buses,
        reference_curve_nash_max_iterations(inputs),
        maximum_number_of_segments_in_nash_equilibrium(inputs),
    )
    bg_price_output = zeros(
        Float64,
        number_of_bidding_groups,
        number_of_buses,
        reference_curve_nash_max_iterations(inputs),
        maximum_number_of_segments_in_nash_equilibrium(inputs),
    )
    bg_slope_output = fill(
        Inf,
        number_of_bidding_groups,
        number_of_buses,
        reference_curve_nash_max_iterations(inputs),
        maximum_number_of_segments_in_nash_equilibrium(inputs),
    )

    for bus in buses
        q, p, b = treat_bidding_group_data(
            inputs,
            bg_original_quantity_bid,
            bg_original_price_bid,
            bus,
        )
        original_q = deepcopy(q)
        original_p = deepcopy(p)
        original_b = deepcopy(b)
        for iter in 1:reference_curve_nash_max_iterations(inputs)
            q, p, b = run_reference_curve_nash_iteration(
                inputs,
                number_of_bidding_groups;
                current_quantity = q,
                current_price = p,
                current_slope = b,
                original_quantity = original_q,
                original_price = original_p,
                original_slope = original_b,
            )
            for i in 1:number_of_bidding_groups
                number_of_segments = length(q[i])
                bg_quantity_output[i, bus, iter, 1:number_of_segments] = q[i]
                bg_price_output[i, bus, iter, 1:number_of_segments] = p[i]
                bg_slope_output[i, bus, iter, 1:number_of_segments] = b[i]
            end
        end
    end

    write_reference_curve_nash_bg_outputs(
        inputs,
        outputs,
        run_time_options,
        bg_quantity_output,
        bg_price_output,
        bg_slope_output,
        period,
        scenario,
    )

    return nothing
end

function treat_reference_curve_data(
    inputs::AbstractInputs,
    quantity::Array{Float64, 3},
    price::Array{Float64, 3},
    vr_index::Int,
)
    asset_owners_in_virtual_reservoir = virtual_reservoir_asset_owner_indices(inputs, vr_index)
    number_of_asset_owners_in_virtual_reservoir = length(asset_owners_in_virtual_reservoir)

    treated_quantity_bids = Vector{Vector{Float64}}(undef, number_of_asset_owners_in_virtual_reservoir)
    treated_price_bids = Vector{Vector{Float64}}(undef, number_of_asset_owners_in_virtual_reservoir)
    treated_slopes = Vector{Vector{Float64}}(undef, number_of_asset_owners_in_virtual_reservoir)

    for (i, ao) in enumerate(asset_owners_in_virtual_reservoir)
        treated_quantity_bids[i], treated_price_bids[i] = remove_redundant_reference_curve_segments(
            quantity[vr_index, ao, :],
            price[vr_index, ao, :],
        )
        treated_quantity_bids[i] = quantity_points_from_segments(treated_quantity_bids[i])
        treated_quantity_bids[i], treated_price_bids[i] = reverse_bid_order_and_add_point(
            inputs,
            treated_quantity_bids[i],
            treated_price_bids[i],
        )
        treated_slopes[i] = diff(treated_price_bids[i]) ./ diff(treated_quantity_bids[i])
    end

    validate_nash_input_data(
        inputs,
        treated_quantity_bids,
        treated_price_bids,
        treated_slopes,
        vr_index,
    )

    return treated_quantity_bids, treated_price_bids, treated_slopes
end

function treat_bidding_group_data(
    inputs::AbstractInputs,
    quantity::Array{Float64, 4},
    price::Array{Float64, 4},
    bus_index::Int,
)
    bidding_groups = index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
    number_of_bidding_groups = length(bidding_groups)
    # Input dimensions are (bidding_group, bus, segment, subperiod)
    # Aggregated dimensions are (bidding_group, segment)
    # "dims = 3" means we are summing over the fourth dimension (subperiod), because accessing the scalar "bus_index" dimension transforms the data into a 3D array
    aggregated_quantity = dropdims(sum(quantity[bidding_groups, bus_index, :, :]; dims = 3); dims = 3)
    aggregated_price = dropdims(
        sum(price[bidding_groups, bus_index, :, :] .* quantity[bidding_groups, bus_index, :, :]; dims = 3) ./
        aggregated_quantity;
        dims = 3,
    )

    treated_quantity_bids = Vector{Vector{Float64}}(undef, number_of_bidding_groups)
    treated_price_bids = Vector{Vector{Float64}}(undef, number_of_bidding_groups)
    treated_slopes = Vector{Vector{Float64}}(undef, number_of_bidding_groups)

    for (i, bg) in enumerate(bidding_groups)
        treated_quantity_bids[i], treated_price_bids[i] = remove_redundant_reference_curve_segments(
            aggregated_quantity[i, :],
            aggregated_price[i, :],
        )
        treated_quantity_bids[i] = quantity_points_from_segments(treated_quantity_bids[i])
        treated_quantity_bids[i], treated_price_bids[i] = reverse_bid_order_and_add_point(
            inputs,
            treated_quantity_bids[i],
            treated_price_bids[i],
        )
        treated_slopes[i] = diff(treated_price_bids[i]) ./ diff(treated_quantity_bids[i])
    end

    return treated_quantity_bids, treated_price_bids, treated_slopes
end

function remove_redundant_reference_curve_segments(
    quantity::Vector{Float64},
    price::Vector{Float64},
)
    new_price = unique(price)
    number_of_unique_prices = length(new_price)

    new_quantity = zeros(number_of_unique_prices)
    for i in 1:number_of_unique_prices
        positions = findall(price .== new_price[i])
        new_quantity[i] = sum(quantity[positions])
    end

    if new_price[end] == 0.0 && new_quantity[end] == 0.0
        new_price = new_price[1:end-1]
        new_quantity = new_quantity[1:end-1]
    end

    return new_quantity, new_price
end

function quantity_points_from_segments(
    quantity::Vector{Float64},
)
    number_of_points = length(quantity)
    new_quantity = zeros(number_of_points)

    for i in 1:number_of_points
        new_quantity[i] = sum(quantity[1:i])
    end

    return new_quantity
end

function reverse_bid_order_and_add_point(
    inputs::AbstractInputs,
    quantity::Vector{Float64},
    price::Vector{Float64},
)
    new_quantity = vcat((quantity[end] + reference_curve_nash_extra_bid_quantity(inputs)), reverse(quantity))
    new_price = vcat(demand_deficit_cost(inputs), reverse(price))

    return new_quantity, new_price
end

function validate_nash_input_data(
    inputs::AbstractInputs,
    quantity::Vector{Vector{Float64}},
    price::Vector{Vector{Float64}},
    slope::Vector{Vector{Float64}},
    vr_index::Int,
)
    asset_owners_in_virtual_reservoir = virtual_reservoir_asset_owner_indices(inputs, vr_index)

    for (i, ao) in enumerate(asset_owners_in_virtual_reservoir)
        @assert all(slope[i] .> reference_curve_nash_tolerance(inputs)) "Reference bid curve for asset owner $(asset_owner_label(inputs, ao)) in virtual reservoir $(virtual_reservoir_label(inputs, vr_index)) has a segment with slope below the tolerance: $(slope[i])"
        @assert all(price[i] .<= reference_curve_nash_max_cost_multiplier(inputs) * demand_deficit_cost(inputs)) "Reference bid curve for asset owner $(asset_owner_label(inputs, ao)) in virtual reservoir $(virtual_reservoir_label(inputs, vr_index)) has a price point above the demand deficit cost: $(price[i])"
    end

    return nothing
end

function run_reference_curve_nash_iteration(
    inputs::AbstractInputs,
    number_of_asset_owners::Int;
    current_quantity::Vector{Vector{Float64}},
    current_price::Vector{Vector{Float64}},
    current_slope::Vector{Vector{Float64}},
    original_quantity::Vector{Vector{Float64}},
    original_price::Vector{Vector{Float64}},
    original_slope::Vector{Vector{Float64}},
)
    new_quantity = Vector{Vector{Float64}}(undef, number_of_asset_owners)
    new_price = Vector{Vector{Float64}}(undef, number_of_asset_owners)
    new_slope = Vector{Vector{Float64}}(undef, number_of_asset_owners)

    # Get the first segment for each agent
    segment = 1
    for i in 1:number_of_asset_owners
        new_quantity[i] = [current_quantity[i][segment]]
        new_price[i] = [reference_curve_nash_max_cost_multiplier(inputs) * demand_deficit_cost(inputs)]
        new_slope[i] = [update_slope(inputs, current_slope, original_slope, segment)[i]]
    end

    # Iterate over the segments
    for segment in 1:number_of_segments_for_vr_in_nash_equilibrium(inputs, number_of_asset_owners)
        minimum_quantities = [minimum(original_quantity[i]) for i in 1:number_of_asset_owners]
        if maximum(
            [new_quantity[i][segment] for i in 1:number_of_asset_owners] - minimum_quantities,
        ) == 0
            break
        end

        next_quantity, next_price = get_next_point(
            inputs,
            new_quantity,
            new_price,
            new_slope,
            original_quantity,
            number_of_asset_owners,
            segment,
        )

        current_segment = get_current_segment(
            inputs,
            next_quantity,
            original_quantity,
            current_quantity,
            number_of_asset_owners,
        )
        true_segment = get_current_segment(
            inputs,
            next_quantity,
            original_quantity,
            original_quantity,
            number_of_asset_owners,
        )

        next_slope = fill(Inf, number_of_asset_owners)
        true_slope = fill(Inf, number_of_asset_owners)
        for i in 1:number_of_asset_owners
            if true_segment[i] > 0
                next_slope[i] = current_slope[i][current_segment[i]]
                true_slope[i] = original_slope[i][true_segment[i]]
            end
        end

        next_slope = update_slope(
            inputs,
            [[next_slope[i] for _ in 1:segment] for i in 1:number_of_asset_owners],
            [[true_slope[i] for _ in 1:segment] for i in 1:number_of_asset_owners],
            segment,
        ) # TODO: improve this

        for i in 1:number_of_asset_owners
            push!(new_quantity[i], next_quantity[i])
            push!(new_price[i], next_price)
            push!(new_slope[i], next_slope[i])
        end

        test_inversion(
            inputs,
            original_quantity,
            original_price,
            original_slope,
            new_quantity,
            new_price,
            number_of_asset_owners,
        )
    end

    return new_quantity, new_price, new_slope
end

function update_slope(
    inputs::AbstractInputs,
    current_slope::Vector{Vector{Float64}},
    original_slope::Vector{Vector{Float64}},
    segment_index::Int,
)
    current_slope_in_segment = [current_slope[i][segment_index] for i in 1:length(current_slope)]
    original_slope_in_segment = [original_slope[i][segment_index] for i in 1:length(original_slope)]

    B_k = sum(1 ./ current_slope_in_segment)
    new_slope =
        original_slope_in_segment ./ 2 .+ 1 / B_k + sqrt.(((original_slope_in_segment ./ 2) .^ 2) .+ (1 / B_k)^2)

    agent_indexes = findall(isfinite, original_slope_in_segment)

    if length(agent_indexes) < 3
        new_slope[agent_indexes] .= reference_curve_nash_tolerance(inputs)
    end

    return new_slope
end

function get_next_point(
    inputs::AbstractInputs,
    current_quantity::Vector{Vector{Float64}},
    current_price::Vector{Vector{Float64}},
    current_slope::Vector{Vector{Float64}},
    original_quantity::Vector{Vector{Float64}},
    number_of_asset_owners::Int,
    segment_index::Int,
)
    current_quantity_in_segment =
        [current_quantity[i][segment_index] for i in 1:number_of_asset_owners]
    current_price_in_segment = current_price[1][segment_index]
    current_slope_in_segment = [current_slope[i][segment_index] for i in 1:number_of_asset_owners]

    price_delta = get_price_delta(
        inputs,
        current_quantity,
        current_slope,
        original_quantity,
        number_of_asset_owners,
        segment_index,
    )

    next_price = current_price_in_segment .- price_delta
    next_quantity = round.(current_quantity_in_segment .- (price_delta ./ current_slope_in_segment), digits = 13)

    return next_quantity, next_price
end

function get_price_delta(
    inputs::AbstractInputs,
    current_quantity::Vector{Vector{Float64}},
    current_slope::Vector{Vector{Float64}},
    original_quantity::Vector{Vector{Float64}},
    number_of_asset_owners::Int,
    segment_index::Int,
)
    current_slope_in_segment = [current_slope[i][segment_index] for i in 1:number_of_asset_owners]

    available_quantities = get_available_quantities(
        inputs,
        current_quantity,
        original_quantity,
        number_of_asset_owners,
        segment_index,
    )

    price_delta = 0.0
    available_asset_owners = findall(available_quantities .> 0.0)
    if !isempty(available_asset_owners)
        price_delta = minimum(
            available_quantities[available_asset_owners] .* current_slope_in_segment[available_asset_owners],
        )
    end

    return price_delta
end

function get_available_quantities(
    inputs::AbstractInputs,
    current_quantity::Vector{Vector{Float64}},
    original_quantity::Vector{Vector{Float64}},
    number_of_asset_owners::Int,
    segment_index::Int,
)
    current_quantity_in_segment =
        [current_quantity[i][segment_index] for i in 1:number_of_asset_owners]

    segments = get_current_segment(
        inputs,
        current_quantity_in_segment,
        original_quantity,
        original_quantity,
        number_of_asset_owners,
    )

    available_quantities = zeros(number_of_asset_owners)
    for i in 1:number_of_asset_owners
        minimum_quantity = original_quantity[i][segments[i]+1]
        available_quantities[i] = max(current_quantity[i][segment_index] - minimum_quantity, 0)
    end

    return available_quantities
end

function get_current_segment(
    inputs::AbstractInputs,
    current_quantity_in_segment::Vector{Float64},
    original_quantity::Vector{Vector{Float64}},
    reference_quantity::Vector{Vector{Float64}},
    number_of_asset_owners::Int,
)
    segments = zeros(Int64, number_of_asset_owners)
    minimum_quantities = [minimum(original_quantity[i]) for i in 1:number_of_asset_owners]

    for i in 1:number_of_asset_owners
        if current_quantity_in_segment[i] > minimum_quantities[i]
            idx = findfirst(reference_quantity[i] .< current_quantity_in_segment[i])
            if isnothing(idx)
                segments[i] = number_of_segments_for_vr_in_nash_equilibrium(inputs, number_of_asset_owners)
            else
                segments[i] = idx - 1
            end
        end
    end

    return segments
end

function test_inversion(
    inputs::AbstractInputs,
    original_quantity::Vector{Vector{Float64}},
    original_price::Vector{Vector{Float64}},
    original_slope::Vector{Vector{Float64}},
    new_quantity::Vector{Vector{Float64}},
    new_price::Vector{Vector{Float64}},
    number_of_asset_owners::Int,
)
    quantity_in_segment = [new_quantity[i][end] for i in 1:number_of_asset_owners]
    price_in_segment = new_price[1][end]
    quantity_in_previous_segment = [new_quantity[i][end-1] for i in 1:number_of_asset_owners]

    test_segment = get_current_segment(
        inputs,
        quantity_in_previous_segment,
        original_quantity,
        original_quantity,
        number_of_asset_owners,
    )

    agent_indexes = findall(test_segment .> 0)
    original_quantity_in_segment = [original_quantity[i][test_segment[i]] for i in agent_indexes]
    original_price_in_segment = [original_price[i][test_segment[i]] for i in agent_indexes]
    original_slope_in_segment = [original_slope[i][test_segment[i]] for i in agent_indexes]

    reference_price =
        original_price_in_segment -
        (original_quantity_in_segment .- quantity_in_segment[agent_indexes]) .* original_slope_in_segment
    price_delta = price_in_segment .- reference_price

    if any(price_delta .< 0)
        @warn("Curve inversion")
    end

    return nothing
end

function maximum_number_of_segments_in_nash_equilibrium(inputs::AbstractInputs)
    return reference_curve_number_of_segments(inputs) * max(
        number_of_elements(inputs, AssetOwner),
        number_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs]),
    ) + 1
end

function number_of_segments_for_vr_in_nash_equilibrium(
    inputs::AbstractInputs,
    number_of_asset_owners_in_vr::Int,
)
    return reference_curve_number_of_segments(inputs) * number_of_asset_owners_in_vr
end

function initialize_reference_curve_nash_outputs(
    inputs::AbstractInputs,
    run_time_options::RunTimeOptions,
)
    outputs = Outputs()

    vr_labels = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.virtual_reservoir,
        inputs.collections.asset_owner;
        index_getter = virtual_reservoir_asset_owner_indices,
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "virtual_reservoir_nash_quantity",
        dimensions = ["period", "scenario", "nash_iteration", "nash_curve_segment"],
        unit = "MWh",
        labels = vr_labels,
        run_time_options,
    )
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "virtual_reservoir_nash_price",
        dimensions = ["period", "scenario", "nash_iteration", "nash_curve_segment"],
        unit = "\$/MWh",
        labels = vr_labels,
        run_time_options,
    )
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "virtual_reservoir_nash_slope",
        dimensions = ["period", "scenario", "nash_iteration", "nash_curve_segment"],
        unit = "\$/MWh2",
        labels = vr_labels,
        run_time_options,
    )

    if !any_elements(inputs, BiddingGroup) || !has_any_simple_bids(inputs)
        return outputs
    end

    bg_labels = labels_for_output_by_pair_of_agents(
        inputs,
        run_time_options,
        inputs.collections.bidding_group,
        inputs.collections.bus;
        index_getter = all_buses,
        filters_to_apply_in_first_collection = [has_generation_besides_virtual_reservoirs],
    )

    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "bidding_group_nash_quantity",
        dimensions = ["period", "scenario", "subperiod", "nash_iteration", "nash_curve_segment"],
        unit = "MWh",
        labels = bg_labels,
        run_time_options,
    )
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "bidding_group_nash_price",
        dimensions = ["period", "scenario", "subperiod", "nash_iteration", "nash_curve_segment"],
        unit = "\$/MWh",
        labels = bg_labels,
        run_time_options,
    )
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "bidding_group_nash_slope",
        dimensions = ["period", "scenario", "subperiod", "nash_iteration", "nash_curve_segment"],
        unit = "\$/MWh2",
        labels = bg_labels,
        run_time_options,
    )

    return outputs
end

function write_reference_curve_nash_vr_outputs(
    inputs::AbstractInputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    quantity::Array{Float64, 4},
    price::Array{Float64, 4},
    slope::Array{Float64, 4},
    period::Int,
    scenario::Int,
)
    write_nash_equilibrium_vr_output!(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_nash_quantity",
        quantity,
        period,
        scenario,
    )

    write_nash_equilibrium_vr_output!(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_nash_price",
        price,
        period,
        scenario,
    )

    write_nash_equilibrium_vr_output!(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_nash_slope",
        slope,
        period,
        scenario,
    )

    return nothing
end

function write_reference_curve_nash_bg_outputs(
    inputs::AbstractInputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    quantity::Array{Float64, 4},
    price::Array{Float64, 4},
    slope::Array{Float64, 4},
    period::Int,
    scenario::Int,
)
    reshaped_quantity, reshaped_price, reshaped_slope =
        disaggregate_bg_output_in_subperiods(inputs, quantity, price, slope)

    write_nash_equilibrium_bg_output!(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_nash_quantity",
        reshaped_quantity,
        period,
        scenario,
    )

    write_nash_equilibrium_bg_output!(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_nash_price",
        reshaped_price,
        period,
        scenario,
    )

    write_nash_equilibrium_bg_output!(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_nash_slope",
        reshaped_slope,
        period,
        scenario,
    )

    return nothing
end

function disaggregate_bg_output_in_subperiods(
    inputs::AbstractInputs,
    quantity::Array{Float64, 4},
    price::Array{Float64, 4},
    slope::Array{Float64, 4},
)
    number_of_bidding_groups, number_of_buses, number_of_iterations, number_of_segments = size(quantity)
    subperiod_duration_sum = sum(subperiod_duration_in_hours(inputs))

    reshaped_quantity = zeros(
        Float64,
        number_of_bidding_groups,
        number_of_buses,
        number_of_subperiods(inputs),
        number_of_iterations,
        number_of_segments,
    )
    reshaped_price = zeros(
        Float64,
        number_of_bidding_groups,
        number_of_buses,
        number_of_subperiods(inputs),
        number_of_iterations,
        number_of_segments,
    )
    reshaped_slope = zeros(
        Float64,
        number_of_bidding_groups,
        number_of_buses,
        number_of_subperiods(inputs),
        number_of_iterations,
        number_of_segments,
    )

    for subperiod in subperiods(inputs)
        duration = subperiod_duration_in_hours(inputs, subperiod)
        reshaped_quantity[:, :, subperiod, :, :] .= quantity .* (duration / subperiod_duration_sum) # quantity is divided into the subperiods
        reshaped_price[:, :, subperiod, :, :] .= price # price is repeated
        reshaped_slope[:, :, subperiod, :, :] .= slope .* (subperiod_duration_sum / duration) # slope is multiplied by the inverse of the quantity factor
    end

    return reshaped_quantity, reshaped_price, reshaped_slope
end
