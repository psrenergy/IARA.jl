function nash_bids_from_hydro_reference_curve(
    inputs::AbstractInputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    period::Int = 1,
    scenario::Int = 1,
)
    original_quantity_bid, original_price_bid =
        read_serialized_virtual_reservoir_heuristic_bids(inputs; period, scenario)

    virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)

    number_of_virtual_reservoirs = length(virtual_reservoirs)
    number_of_asset_owners = number_of_elements(inputs, AssetOwner)

    quantity_output = zeros(
        Float64,
        number_of_virtual_reservoirs,
        number_of_asset_owners,
        reference_curve_nash_max_iterations(inputs),
        maximum_number_of_segments_in_nash_equilibrium(inputs),
    )
    price_output = zeros(
        Float64,
        number_of_virtual_reservoirs,
        number_of_asset_owners,
        reference_curve_nash_max_iterations(inputs),
        maximum_number_of_segments_in_nash_equilibrium(inputs),
    )
    slope_output = fill(
        Inf,
        number_of_virtual_reservoirs,
        number_of_asset_owners,
        reference_curve_nash_max_iterations(inputs),
        maximum_number_of_segments_in_nash_equilibrium(inputs),
    )

    for vr in virtual_reservoirs
        q, p, b = treat_reference_curve_data(
            inputs,
            original_quantity_bid,
            original_price_bid,
            vr,
        )
        original_q = deepcopy(q)
        original_p = deepcopy(p)
        original_b = deepcopy(b)
        for iter in 1:reference_curve_nash_max_iterations(inputs)
            q, p, b = run_reference_curve_nash_iteration(
                inputs,
                vr;
                current_quantity = q,
                current_price = p,
                current_slope = b,
                original_quantity = original_q,
                original_price = original_p,
                original_slope = original_b,
            )
            for (i, ao) in enumerate(virtual_reservoir_asset_owner_indices(inputs, vr))
                number_of_segments = length(q[i])
                quantity_output[vr, ao, iter, 1:number_of_segments] = q[i]
                price_output[vr, ao, iter, 1:number_of_segments] = p[i]
                slope_output[vr, ao, iter, 1:number_of_segments] = b[i]
            end
        end
    end

    write_reference_curve_nash_outputs(
        inputs,
        outputs,
        run_time_options,
        quantity_output,
        price_output,
        slope_output,
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
        @assert all(slope[i] .> reference_curve_nash_tolerance(inputs)) "Reference bid curve for asset owner $(asset_owner_labels(inputs, ao)) in virtual reservoir $(virtual_reservoir_labels(inputs, vr_index)) has a segment with slope below the tolerance."
        @assert all(price[i] .<= 2.0 * demand_deficit_cost(inputs)) "Reference bid curve for asset owner $(asset_owner_labels(inputs, ao)) in virtual reservoir $(virtual_reservoir_labels(inputs, vr_index)) has a price point above the demand deficit cost."
    end

    return nothing
end

function run_reference_curve_nash_iteration(
    inputs::AbstractInputs,
    vr_index::Int;
    current_quantity::Vector{Vector{Float64}},
    current_price::Vector{Vector{Float64}},
    current_slope::Vector{Vector{Float64}},
    original_quantity::Vector{Vector{Float64}},
    original_price::Vector{Vector{Float64}},
    original_slope::Vector{Vector{Float64}},
)
    asset_owners_in_virtual_reservoir = virtual_reservoir_asset_owner_indices(inputs, vr_index)
    number_of_asset_owners_in_virtual_reservoir = length(asset_owners_in_virtual_reservoir)

    new_quantity = Vector{Vector{Float64}}(undef, number_of_asset_owners_in_virtual_reservoir)
    new_price = Vector{Vector{Float64}}(undef, number_of_asset_owners_in_virtual_reservoir)
    new_slope = Vector{Vector{Float64}}(undef, number_of_asset_owners_in_virtual_reservoir)

    # Get the first segment for each agent
    segment = 1
    for (i, ao) in enumerate(asset_owners_in_virtual_reservoir)
        new_quantity[i] = [current_quantity[i][segment]]
        new_price[i] = [2.0 * demand_deficit_cost(inputs)]
        new_slope[i] = [update_slope(inputs, current_slope, original_slope, segment)[i]]
    end

    # Iterate over the segments
    for segment in 1:maximum_number_of_segments_in_nash_equilibrium(inputs)
        minimum_quantities = [minimum(original_quantity[i]) for i in 1:number_of_asset_owners_in_virtual_reservoir]
        if maximum(
            [new_quantity[i][segment] for i in 1:number_of_asset_owners_in_virtual_reservoir] - minimum_quantities,
        ) == 0
            break
        end

        next_quantity, next_price = get_next_point(
            inputs,
            new_quantity,
            new_price,
            new_slope,
            original_quantity,
            vr_index,
            segment,
        )

        current_segment = get_current_segment(
            inputs,
            next_quantity,
            original_quantity,
            current_quantity,
            vr_index,
        )
        true_segment = get_current_segment(
            inputs,
            next_quantity,
            original_quantity,
            original_quantity,
            vr_index,
        )

        next_slope = fill(Inf, number_of_asset_owners_in_virtual_reservoir)
        true_slope = fill(Inf, number_of_asset_owners_in_virtual_reservoir)
        for (i, ao) in enumerate(asset_owners_in_virtual_reservoir)
            if true_segment[i] > 0
                next_slope[i] = current_slope[i][current_segment[i]]
                true_slope[i] = original_slope[i][true_segment[i]]
            end
        end

        next_slope = update_slope(
            inputs,
            [[next_slope[i] for _ in 1:segment] for i in 1:number_of_asset_owners_in_virtual_reservoir],
            [[true_slope[i] for _ in 1:segment] for i in 1:number_of_asset_owners_in_virtual_reservoir],
            segment,
        ) # TODO: improve this

        for (i, ao) in enumerate(asset_owners_in_virtual_reservoir)
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
            vr_index,
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
    vr_index::Int,
    segment_index::Int,
)
    asset_owners_in_virtual_reservoir = virtual_reservoir_asset_owner_indices(inputs, vr_index)
    number_of_asset_owners_in_virtual_reservoir = length(asset_owners_in_virtual_reservoir)

    current_quantity_in_segment =
        [current_quantity[i][segment_index] for i in 1:number_of_asset_owners_in_virtual_reservoir]
    current_price_in_segment = current_price[1][segment_index]
    current_slope_in_segment = [current_slope[i][segment_index] for i in 1:number_of_asset_owners_in_virtual_reservoir]

    price_delta = get_price_delta(
        inputs,
        current_quantity,
        current_slope,
        original_quantity,
        vr_index,
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
    vr_index::Int,
    segment_index::Int,
)
    asset_owners_in_virtual_reservoir = virtual_reservoir_asset_owner_indices(inputs, vr_index)
    number_of_asset_owners_in_virtual_reservoir = length(asset_owners_in_virtual_reservoir)

    current_slope_in_segment = [current_slope[i][segment_index] for i in 1:number_of_asset_owners_in_virtual_reservoir]

    available_quantities = get_available_quantities(
        inputs,
        current_quantity,
        original_quantity,
        vr_index,
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
    vr_index::Int,
    segment_index::Int,
)
    asset_owners_in_virtual_reservoir = virtual_reservoir_asset_owner_indices(inputs, vr_index)
    number_of_asset_owners_in_virtual_reservoir = length(asset_owners_in_virtual_reservoir)

    current_quantity_in_segment =
        [current_quantity[i][segment_index] for i in 1:number_of_asset_owners_in_virtual_reservoir]

    segments = get_current_segment(
        inputs,
        current_quantity_in_segment,
        original_quantity,
        original_quantity,
        vr_index,
    )

    available_quantities = zeros(number_of_asset_owners_in_virtual_reservoir)
    for (i, ao) in enumerate(asset_owners_in_virtual_reservoir)
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
    vr_index::Int,
)
    asset_owners_in_virtual_reservoir = virtual_reservoir_asset_owner_indices(inputs, vr_index)
    number_of_asset_owners_in_virtual_reservoir = length(asset_owners_in_virtual_reservoir)
    segments = zeros(Int64, number_of_asset_owners_in_virtual_reservoir)

    minimum_quantities = [minimum(original_quantity[i]) for i in 1:number_of_asset_owners_in_virtual_reservoir]

    for (i, ao) in enumerate(asset_owners_in_virtual_reservoir)
        if current_quantity_in_segment[i] > minimum_quantities[i]
            idx = findfirst(reference_quantity[i] .< current_quantity_in_segment[i])
            if isnothing(idx)
                segments[i] = maximum_number_of_segments_in_nash_equilibrium(inputs)
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
    vr_index::Int,
)
    asset_owners_in_virtual_reservoir = virtual_reservoir_asset_owner_indices(inputs, vr_index)
    number_of_asset_owners_in_virtual_reservoir = length(asset_owners_in_virtual_reservoir)

    quantity_in_segment = [new_quantity[i][end] for i in 1:number_of_asset_owners_in_virtual_reservoir]
    price_in_segment = new_price[1][end]
    quantity_in_previous_segment = [new_quantity[i][end-1] for i in 1:number_of_asset_owners_in_virtual_reservoir]

    test_segment = get_current_segment(
        inputs,
        quantity_in_previous_segment,
        original_quantity,
        original_quantity,
        vr_index,
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
    return reference_curve_number_of_segments(inputs) * number_of_elements(inputs, AssetOwner)
end

function initialize_reference_curve_nash_outputs(
    inputs::AbstractInputs,
    run_time_options::RunTimeOptions,
)
    outputs = Outputs()

    labels = labels_for_output_by_pair_of_agents(
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
        labels = labels,
        run_time_options,
    )
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "virtual_reservoir_nash_price",
        dimensions = ["period", "scenario", "nash_iteration", "nash_curve_segment"],
        unit = "\$/MWh",
        labels = labels,
        run_time_options,
    )
    initialize!(
        QuiverOutput,
        outputs;
        inputs,
        output_name = "virtual_reservoir_nash_slope",
        dimensions = ["period", "scenario", "nash_iteration", "nash_curve_segment"],
        unit = "\$/MWh2",
        labels = labels,
        run_time_options,
    )

    return outputs
end

function write_reference_curve_nash_outputs(
    inputs::AbstractInputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    quantity::Array{Float64, 4},
    price::Array{Float64, 4},
    slope::Array{Float64, 4},
    period::Int,
    scenario::Int,
)
    write_nash_equilibrium_output!(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_nash_quantity",
        quantity,
        period,
        scenario,
    )

    write_nash_equilibrium_output!(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_nash_price",
        price,
        period,
        scenario,
    )

    write_nash_equilibrium_output!(
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
