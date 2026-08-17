# Data structure to map agents back to their source (VR or BG at specific location)
struct AgentMapping
    agent_index_in_global::Int       # Index in the global q, p, b vectors
    source_type::Symbol              # :vr or :bg
    location_index::Int              # VR index or Bus index
    agent_local_index::Int           # Index within the VR's asset owners or BG index
    original_agent_id::Int           # Asset owner ID or Bidding group ID
end

function supply_function_equilibrium(
    inputs::AbstractInputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions,
    period::Int = 1,
    scenario::Int = 1,
)
    # Prepare virtual reservoir data if applicable
    virtual_reservoirs = Int[]
    number_of_virtual_reservoirs = 0
    number_of_asset_owners = 0
    vr_original_quantity_bid = nothing
    vr_original_price_bid = nothing
    vr_quantity_output = nothing
    vr_price_output = nothing
    vr_slope_output = nothing
    has_virtual_reservoirs = use_virtual_reservoirs(inputs)

    if has_virtual_reservoirs
        vr_original_quantity_bid, vr_original_price_bid =
            read_serialized_virtual_reservoir_heuristic_bids(inputs; period, scenario)

        virtual_reservoirs = index_of_elements(inputs, VirtualReservoir)
        number_of_virtual_reservoirs = length(virtual_reservoirs)
        number_of_asset_owners = number_of_elements(inputs, AssetOwner)

        vr_quantity_output = zeros(
            Float64,
            number_of_virtual_reservoirs,
            number_of_asset_owners,
            supply_function_equilibrium_max_iterations(inputs),
            maximum_number_of_segments_in_supply_function_equilibrium(inputs),
        )
        vr_price_output = zeros(
            Float64,
            number_of_virtual_reservoirs,
            number_of_asset_owners,
            supply_function_equilibrium_max_iterations(inputs),
            maximum_number_of_segments_in_supply_function_equilibrium(inputs),
        )
        vr_slope_output = fill(
            Inf,
            number_of_virtual_reservoirs,
            number_of_asset_owners,
            supply_function_equilibrium_max_iterations(inputs),
            maximum_number_of_segments_in_supply_function_equilibrium(inputs),
        )
    end

    # Prepare bidding group data if applicable
    buses = Int[]
    bidding_groups = Int[]
    number_of_buses = 0
    number_of_bidding_groups = 0
    bg_original_quantity_bid = nothing
    bg_original_price_bid = nothing
    bg_quantity_output = nothing
    bg_price_output = nothing
    bg_slope_output = nothing
    has_bidding_groups = any_elements(inputs, BiddingGroup) && has_any_simple_bids(inputs)

    if has_bidding_groups
        bg_original_quantity_bid, bg_original_price_bid = read_serialized_heuristic_bids(inputs; period, scenario)

        buses = index_of_elements(inputs, Bus)
        bidding_groups =
            index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
        number_of_buses = length(buses)
        number_of_bidding_groups = length(bidding_groups)

        bg_quantity_output = zeros(
            Float64,
            number_of_bidding_groups,
            number_of_buses,
            supply_function_equilibrium_max_iterations(inputs),
            maximum_number_of_segments_in_supply_function_equilibrium(inputs),
        )
        bg_price_output = zeros(
            Float64,
            number_of_bidding_groups,
            number_of_buses,
            supply_function_equilibrium_max_iterations(inputs),
            maximum_number_of_segments_in_supply_function_equilibrium(inputs),
        )
        bg_slope_output = fill(
            Inf,
            number_of_bidding_groups,
            number_of_buses,
            supply_function_equilibrium_max_iterations(inputs),
            maximum_number_of_segments_in_supply_function_equilibrium(inputs),
        )
    end

    # Aggregate all bids into a single (q, p, b) triple
    # Build mapping to track which agent corresponds to which VR/bus
    agent_mappings = AgentMapping[]
    global_q = Vector{Vector{Float64}}()
    global_p = Vector{Vector{Float64}}()
    global_b = Vector{Vector{Float64}}()
    global_price_type = Vector{AssetOwner_PriceType.T}()
    global_agent_index = 0

    # Add all VR bids
    if has_virtual_reservoirs
        for vr in virtual_reservoirs
            asset_owners_in_vr = virtual_reservoir_asset_owner_indices(inputs, vr)
            q, p, b = treat_reference_curve_data(
                inputs,
                vr_original_quantity_bid,
                vr_original_price_bid,
                vr,
            )
            for (local_idx, ao) in enumerate(asset_owners_in_vr)
                global_agent_index += 1
                price_type = asset_owner_price_type(inputs, ao)
                push!(global_price_type, price_type)
                push!(global_q, q[local_idx])
                push!(global_p, p[local_idx])
                push!(global_b, b[local_idx])
                push!(
                    agent_mappings,
                    AgentMapping(global_agent_index, :vr, vr, local_idx, ao),
                )
            end
        end
    end

    # Add all BG bids
    if has_bidding_groups
        for bus in buses
            q, p, b = treat_bidding_group_data(
                inputs,
                bg_original_quantity_bid,
                bg_original_price_bid,
                bus,
            )
            for (local_idx, bg) in enumerate(bidding_groups)
                global_agent_index += 1
                price_type = asset_owner_price_type(inputs, bidding_group_asset_owner_index(inputs, bg))
                push!(global_price_type, price_type)
                push!(global_q, q[local_idx])
                push!(global_p, p[local_idx])
                push!(global_b, b[local_idx])
                push!(
                    agent_mappings,
                    AgentMapping(global_agent_index, :bg, bus, local_idx, bg),
                )
            end
        end
    end

    # Store original bids
    original_global_q = deepcopy(global_q)
    original_global_p = deepcopy(global_p)
    original_global_b = deepcopy(global_b)

    total_number_of_agents = length(global_q)

    # Run unified Nash iteration on ALL bids simultaneously
    for iter in 1:supply_function_equilibrium_max_iterations(inputs)
        global_q, global_p, global_b = run_supply_function_equilibrium_iteration(
            inputs,
            total_number_of_agents,
            global_price_type;
            current_quantity = global_q,
            current_price = global_p,
            current_slope = global_b,
            original_quantity = original_global_q,
            original_price = original_global_p,
            original_slope = original_global_b,
        )

        # Disaggregate results back to VR and BG outputs
        for mapping in agent_mappings
            agent_idx = mapping.agent_index_in_global
            number_of_segments = length(global_q[agent_idx])

            if mapping.source_type == :vr
                vr = mapping.location_index
                ao = mapping.original_agent_id
                vr_quantity_output[vr, ao, iter, 1:number_of_segments] = global_q[agent_idx]
                vr_price_output[vr, ao, iter, 1:number_of_segments] = global_p[agent_idx]
                vr_slope_output[vr, ao, iter, 1:number_of_segments] = global_b[agent_idx]
            elseif mapping.source_type == :bg
                bus = mapping.location_index
                bg_local_idx = mapping.agent_local_index
                bg_quantity_output[bg_local_idx, bus, iter, 1:number_of_segments] = global_q[agent_idx]
                bg_price_output[bg_local_idx, bus, iter, 1:number_of_segments] = global_p[agent_idx]
                bg_slope_output[bg_local_idx, bus, iter, 1:number_of_segments] = global_b[agent_idx]
            end
        end
    end

    if has_virtual_reservoirs
        write_supply_function_equilibrium_vr_outputs(
            inputs,
            outputs,
            run_time_options,
            vr_quantity_output,
            vr_price_output,
            vr_slope_output,
            period,
            scenario,
        )
    end

    if has_bidding_groups
        write_supply_function_equilibrium_bg_outputs(
            inputs,
            outputs,
            run_time_options,
            bg_quantity_output,
            bg_price_output,
            bg_slope_output,
            period,
            scenario,
        )
    end

    # Convert the equilibrium curves of the final iteration into clearing bids. We use the loop-exit values of
    # global_q and global_p rather than slicing the output arrays, to avoid depending on their padding.
    vr_quantity_bid, vr_price_bid, bg_quantity_bid, bg_price_bid = supply_function_equilibrium_bids(
        inputs,
        global_q,
        global_p,
        agent_mappings,
    )

    # Shift the whole price curve down by the smallest markup any agent ended up with. The diagnostic
    # `*_sfe_price` outputs written above keep the unshifted equilibrium, so the shift is visible as the difference
    # between them and the `*_sfe_price_bid` outputs below.
    price_shift = supply_function_equilibrium_price_shift(
        agent_mappings,
        vr_price_bid,
        vr_original_price_bid,
        bg_price_bid,
        bg_original_price_bid,
    )

    if has_virtual_reservoirs
        shift_price_bid!(vr_price_bid, price_shift)
    end
    if has_bidding_groups
        shift_price_bid!(bg_price_bid, price_shift)
    end

    if has_virtual_reservoirs
        serialize_virtual_reservoir_supply_function_equilibrium_bids(
            inputs,
            vr_quantity_bid,
            vr_price_bid;
            period,
            scenario,
        )

        write_virtual_reservoir_bid_output(
            outputs,
            inputs,
            run_time_options,
            "virtual_reservoir_sfe_energy_bid",
            vr_quantity_bid,
            period,
            scenario,
        )
        write_virtual_reservoir_bid_output(
            outputs,
            inputs,
            run_time_options,
            "virtual_reservoir_sfe_price_bid",
            vr_price_bid,
            period,
            scenario,
        )
    end

    if has_bidding_groups
        serialize_bidding_group_supply_function_equilibrium_bids(
            inputs,
            bg_quantity_bid,
            bg_price_bid;
            period,
            scenario,
        )

        bidding_group_indexes =
            index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
        write_bid_output(
            outputs,
            inputs,
            run_time_options,
            "bidding_group_sfe_energy_bid",
            # We have to permutate the dimensions because the function expects the dimensions in the order
            # subperiod, bidding_group, bid_segments, bus
            permutedims(bg_quantity_bid[bidding_group_indexes, :, :, :], (4, 1, 3, 2));
            period,
            scenario,
            subscenario = 1,
            filters = [has_generation_besides_virtual_reservoirs],
        )
        write_bid_output(
            outputs,
            inputs,
            run_time_options,
            "bidding_group_sfe_price_bid",
            permutedims(bg_price_bid[bidding_group_indexes, :, :, :], (4, 1, 3, 2));
            period,
            scenario,
            subscenario = 1,
            filters = [has_generation_besides_virtual_reservoirs],
        )
    end

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
        [
            "asset owner $(asset_owner_label(inputs, ao)) in virtual reservoir $(virtual_reservoir_label(inputs, vr_index))"
            for ao in asset_owners_in_virtual_reservoir
        ],
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

    agg_price_nan_indexes = findall(isnan, aggregated_price)
    aggregated_price[agg_price_nan_indexes] .=
        dropdims(sum(price[bidding_groups, bus_index, :, :]; dims = 3); dims = 3)[agg_price_nan_indexes]

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

    validate_nash_input_data(
        inputs,
        treated_quantity_bids,
        treated_price_bids,
        treated_slopes,
        [
            "bidding group $(bidding_group_label(inputs, bg)) in bus $(bus_label(inputs, bus_index))"
            for bg in bidding_groups
        ],
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

    if new_price[end] == 0.0 && new_quantity[end] == 0.0 && length(new_price) > 1
        new_price = new_price[1:end-1]
        new_quantity = new_quantity[1:end-1]
    end

    # Sort by ascending price order
    sorted_indices = sortperm(new_price)
    new_price = new_price[sorted_indices]
    new_quantity = new_quantity[sorted_indices]

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
    new_quantity = vcat((quantity[end] + supply_function_equilibrium_extra_bid_quantity(inputs)), reverse(quantity))
    new_price = vcat(demand_deficit_cost(inputs), reverse(price))

    return new_quantity, new_price
end

function validate_nash_input_data(
    inputs::AbstractInputs,
    quantity::Vector{Vector{Float64}},
    price::Vector{Vector{Float64}},
    slope::Vector{Vector{Float64}},
    agent_labels::Vector{String},
)
    @assert length(agent_labels) == length(slope)

    for i in eachindex(agent_labels)
        @assert all(slope[i] .> supply_function_equilibrium_tolerance(inputs)) "Reference bid curve for $(agent_labels[i]) has a segment with slope below the tolerance: $(slope[i])"
        @assert all(price[i] .<= supply_function_equilibrium_max_cost_multiplier(inputs) * demand_deficit_cost(inputs)) "Reference bid curve for $(agent_labels[i]) has a price point above the demand deficit cost: $(price[i])"
    end

    return nothing
end

"""
    supply_function_equilibrium_bids_from_curve(quantity::Vector{Float64}, price::Vector{Float64}, number_of_bid_segments::Int)

Convert the equilibrium curve of a single agent into incremental quantity and price bids, in the IARA convention.

The equilibrium curve is a list of cumulative quantity points in descending price order, whose first point is the
synthetic point that `reverse_bid_order_and_add_point` added at the demand deficit cost. This function inverts that
representation: it drops the synthetic point, restores the ascending price order, and differentiates the cumulative
quantities back into incremental bids (inverting `quantity_points_from_segments`). The result is trimmed or zero-padded
to `number_of_bid_segments`.
"""
function supply_function_equilibrium_bids_from_curve(
    quantity::Vector{Float64},
    price::Vector{Float64},
    number_of_bid_segments::Int,
)
    @assert length(quantity) == length(price)

    quantity_bids = zeros(number_of_bid_segments)
    price_bids = zeros(number_of_bid_segments)

    # Restore the ascending price order that the bid convention uses. The stored curve runs from the largest
    # cumulative quantity downward, so a bare `diff` of it would yield negative increments for sell bids.
    ascending_quantity = reverse(quantity)
    ascending_price = reverse(price)

    # Drop the synthetic point priced at the demand deficit cost, which is now the last one. Keeping it would add a
    # spurious segment priced at the deficit cost.
    ascending_quantity = ascending_quantity[1:(end-1)]
    ascending_price = ascending_price[1:(end-1)]

    if isempty(ascending_quantity)
        return quantity_bids, price_bids
    end

    # Cumulative quantity points back to incremental segments. The first point is the increment from zero, and the
    # sign of each increment follows the direction of the curve, so purchase (negative quantity) bids invert correctly.
    incremental_quantity = vcat(ascending_quantity[1], diff(ascending_quantity))

    # The equilibrium builds a single price ladder shared by every agent, and an agent's cumulative quantity stays
    # flat over the rungs where it has nothing left to offer. Those rungs differentiate to a zero increment, which is
    # not an offer: keeping them would emit bid segments at prices the agent never bids, interleaved with its real
    # ones. Drop them so the curve is compact and every segment carries quantity.
    segments_with_quantity = findall(!iszero, incremental_quantity)
    incremental_quantity = incremental_quantity[segments_with_quantity]
    ascending_price = ascending_price[segments_with_quantity]

    number_of_valid_segments = length(incremental_quantity)
    if number_of_valid_segments > number_of_bid_segments
        error(
            "The supply function equilibrium produced $(number_of_valid_segments) bid segments, but the model was " *
            "built for $(number_of_bid_segments). This means the analytic bound in " *
            "`maximum_number_of_segments_in_supply_function_equilibrium` is not valid for this case.",
        )
    end

    quantity_bids[1:number_of_valid_segments] = incremental_quantity
    price_bids[1:number_of_valid_segments] = ascending_price

    return quantity_bids, price_bids
end

"""
    supply_function_equilibrium_bids(inputs::AbstractInputs, global_quantity::Vector{Vector{Float64}}, global_price::Vector{Vector{Float64}}, agent_mappings::Vector{AgentMapping})

Convert the equilibrium curves of every agent into clearing bids, in the IARA convention.

Returns `(vr_quantity_bid, vr_price_bid, bg_quantity_bid, bg_price_bid)`, where the virtual reservoir arrays are
indexed by `(virtual_reservoir, asset_owner, bid_segment)` and the bidding group arrays by
`(bidding_group, bus, bid_segment, subperiod)`. Each pair is `nothing` when the corresponding source has no agents.
"""
function supply_function_equilibrium_bids(
    inputs::AbstractInputs,
    global_quantity::Vector{Vector{Float64}},
    global_price::Vector{Vector{Float64}},
    agent_mappings::Vector{AgentMapping},
)
    has_virtual_reservoirs = any(mapping -> mapping.source_type == :vr, agent_mappings)
    has_bidding_groups = any(mapping -> mapping.source_type == :bg, agent_mappings)

    vr_quantity_bid = nothing
    vr_price_bid = nothing
    if has_virtual_reservoirs
        vr_quantity_bid = zeros(
            number_of_elements(inputs, VirtualReservoir),
            number_of_elements(inputs, AssetOwner),
            maximum_number_of_vr_bidding_segments(inputs),
        )
        vr_price_bid = zeros(
            number_of_elements(inputs, VirtualReservoir),
            number_of_elements(inputs, AssetOwner),
            maximum_number_of_vr_bidding_segments(inputs),
        )
    end

    bg_quantity_bid = nothing
    bg_price_bid = nothing
    if has_bidding_groups
        bg_quantity_bid = zeros(
            number_of_elements(inputs, BiddingGroup),
            number_of_elements(inputs, Bus),
            maximum_number_of_bg_bidding_segments(inputs),
            number_of_subperiods(inputs),
        )
        bg_price_bid = zeros(
            number_of_elements(inputs, BiddingGroup),
            number_of_elements(inputs, Bus),
            maximum_number_of_bg_bidding_segments(inputs),
            number_of_subperiods(inputs),
        )
    end

    subperiod_duration_sum = sum(subperiod_duration_in_hours(inputs))

    for mapping in agent_mappings
        agent_index = mapping.agent_index_in_global

        if mapping.source_type == :vr
            vr = mapping.location_index
            ao = mapping.original_agent_id
            quantity_bid, price_bid = supply_function_equilibrium_bids_from_curve(
                global_quantity[agent_index],
                global_price[agent_index],
                maximum_number_of_vr_bidding_segments(inputs),
            )
            vr_quantity_bid[vr, ao, :] = quantity_bid
            vr_price_bid[vr, ao, :] = price_bid
        elseif mapping.source_type == :bg
            bus = mapping.location_index
            bg = mapping.original_agent_id
            quantity_bid, price_bid = supply_function_equilibrium_bids_from_curve(
                global_quantity[agent_index],
                global_price[agent_index],
                maximum_number_of_bg_bidding_segments(inputs),
            )
            # The equilibrium is computed on the subperiod-aggregated curve, so the result is split back across
            # subperiods proportionally to their duration, matching `disaggregate_bg_output_in_subperiods`.
            for subperiod in subperiods(inputs)
                duration_share = subperiod_duration_in_hours(inputs, subperiod) / subperiod_duration_sum
                bg_quantity_bid[bg, bus, :, subperiod] = quantity_bid .* duration_share
                bg_price_bid[bg, bus, :, subperiod] = price_bid
            end
        end
    end

    return vr_quantity_bid, vr_price_bid, bg_quantity_bid, bg_price_bid
end

"""
    supply_function_equilibrium_price_shift(agent_mappings::Vector{AgentMapping}, vr_price_bid, vr_original_price_bid, bg_price_bid, bg_original_price_bid)

Return the downward shift to apply to every agent's equilibrium price curve.

The shift is `min(P_i - C_i)` over all agents `i`, where `P_i` is the equilibrium price and `C_i` the original
reference (cost) price. It is a single scalar for the whole system, so shifting by it preserves the relative position
of the agents' curves, and it is non-negative by construction, so it can only reduce markups.
"""
function supply_function_equilibrium_price_shift(
    agent_mappings::Vector{AgentMapping},
    vr_price_bid::Union{Array{Float64, 3}, Nothing},
    vr_original_price_bid::Union{Array{Float64, 3}, Nothing},
    bg_price_bid::Union{Array{Float64, 4}, Nothing},
    bg_original_price_bid::Union{Array{Float64, 4}, Nothing},
)
    # The gap is measured at the first (lowest price) bid segment of each agent, rather than as the minimum over all
    # of its segments. Because the equilibrium shares one price ladder and the first segment always survives
    # compaction, every agent's `P_i` is the same bottom rung, so this collapses to `P[1] - maximum(C_i[1])`: the
    # highest cost agent sets the shift and ends up exactly at its cost. Measuring at matched quantities, or over all
    # segments, would make the shift depend on the equilibrium's per-agent structure.
    segment = 1

    # Every agent enters the minimum, price takers included. Restricting it to price makers (via the
    # `global_price_type` vector built alongside `agent_mappings`) is a possible future refinement: a price taker
    # bidding near its cost pins the shift close to zero for everyone.
    price_shift = Inf

    # The first segment is the cheapest offer, so it also bounds how far the curve can move before any price would
    # turn negative.
    lowest_equilibrium_price = Inf

    for mapping in agent_mappings
        equilibrium_price, original_price = if mapping.source_type == :vr
            vr = mapping.location_index
            ao = mapping.original_agent_id
            vr_price_bid[vr, ao, segment], vr_original_price_bid[vr, ao, segment]
        else
            bus = mapping.location_index
            bg = mapping.original_agent_id
            # Prices are repeated across subperiods on both curves, so any subperiod gives the same gap.
            bg_price_bid[bg, bus, segment, 1], bg_original_price_bid[bg, bus, segment, 1]
        end

        # An agent whose curve produced no valid segment is left zero padded by
        # `supply_function_equilibrium_bids_from_curve`. It has nothing to offer, so it must not pin the shift.
        if equilibrium_price == 0.0
            continue
        end

        price_shift = min(price_shift, equilibrium_price - original_price)
        lowest_equilibrium_price = min(lowest_equilibrium_price, equilibrium_price)
    end

    if !isfinite(price_shift)
        return 0.0
    end

    # A negative gap means the equilibrium price fell below the reference cost, the same curve inversion that
    # `test_inversion` reports. Shifting by it would raise prices, so the shift is suppressed instead.
    if price_shift < 0.0
        @warn("Equilibrium price below the reference curve cost; the price curve shift was suppressed.")
        return 0.0
    end

    # Nothing downstream enforces a lower bound on bid prices, so the shift is capped here to keep the curve
    # non-negative.
    if price_shift > lowest_equilibrium_price
        @warn(
            "The price curve shift of $(price_shift) would make bid prices negative; " *
            "it was capped at the lowest equilibrium price, $(lowest_equilibrium_price)."
        )
        return lowest_equilibrium_price
    end

    return price_shift
end

"""
    shift_price_bid!(price_bid::Array{Float64}, price_shift::Float64)

Subtract `price_shift` from every bid segment that carries a price.

A zero price marks the trailing padding that `supply_function_equilibrium_bids_from_curve` leaves after an agent's
valid segments, which must stay at zero rather than become `-price_shift`.
"""
function shift_price_bid!(
    price_bid::Array{Float64},
    price_shift::Float64,
)
    for i in eachindex(price_bid)
        if price_bid[i] != 0.0
            price_bid[i] -= price_shift
        end
    end

    return nothing
end

function run_supply_function_equilibrium_iteration(
    inputs::AbstractInputs,
    number_of_asset_owners::Int,
    agents_price_type::Vector{AssetOwner_PriceType.T};
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
        new_price[i] = [supply_function_equilibrium_max_cost_multiplier(inputs) * demand_deficit_cost(inputs)]
        new_slope[i] = [update_slope(inputs, agents_price_type, current_slope, original_slope, segment)[i]]
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
            agents_price_type,
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
    agents_price_type::Vector{AssetOwner_PriceType.T},
    current_slope::Vector{Vector{Float64}},
    original_slope::Vector{Vector{Float64}},
    segment_index::Int,
)
    number_of_agents = length(current_slope)
    @assert length(original_slope) == number_of_agents

    current_slope_in_segment = [current_slope[i][segment_index] for i in 1:number_of_agents]
    original_slope_in_segment = [original_slope[i][segment_index] for i in 1:number_of_agents]
    agent_price_type_weight = zeros(number_of_agents)
    for agent_index in 1:number_of_agents
        agent_price_type_weight[agent_index] = if agents_price_type[agent_index] == AssetOwner_PriceType.PRICE_TAKER
            supply_function_equilibrium_price_taker_weight(inputs)
        else
            1.0
        end
    end

    B_k = sum(agent_price_type_weight ./ current_slope_in_segment)
    new_slope =
        original_slope_in_segment ./ 2 .+ 1 / B_k + sqrt.(((original_slope_in_segment ./ 2) .^ 2) .+ (1 / B_k)^2)

    agent_indexes = findall(isfinite, original_slope_in_segment)

    if length(agent_indexes) < 3
        new_slope[agent_indexes] .= supply_function_equilibrium_tolerance(inputs)
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

"""
    maximum_number_of_segments_in_supply_function_equilibrium(inputs::AbstractInputs; consider_bidding_groups::Bool)

Return an upper bound on the number of segments of an agent's equilibrium curve.

The iteration adds at most one point per price point of the participating agents' original curves, so the bound is the
total number of reference curve segments across all agents, plus the synthetic point at the demand deficit cost.

`consider_bidding_groups` defaults to `has_any_simple_bids(inputs)`, which is only meaningful once the number of
bidding group segments has been set. Callers that run before that must pass it explicitly.
"""
function maximum_number_of_segments_in_supply_function_equilibrium(
    inputs::AbstractInputs;
    consider_bidding_groups::Bool = has_any_simple_bids(inputs),
)
    total_agents = 0

    # Add all VR asset owner pairs
    if use_virtual_reservoirs(inputs)
        for vr in index_of_elements(inputs, VirtualReservoir)
            total_agents += length(virtual_reservoir_asset_owner_indices(inputs, vr))
        end
    end

    # Add all BG bus pairs
    if any_elements(inputs, BiddingGroup) && consider_bidding_groups
        bidding_groups =
            index_of_elements(inputs, BiddingGroup; filters = [has_generation_besides_virtual_reservoirs])
        buses = index_of_elements(inputs, Bus)
        total_agents += length(bidding_groups) * length(buses)
    end

    return reference_curve_number_of_segments(inputs) * total_agents + 1
end

function number_of_segments_for_vr_in_nash_equilibrium(
    inputs::AbstractInputs,
    number_of_asset_owners_in_vr::Int,
)
    return reference_curve_number_of_segments(inputs) * number_of_asset_owners_in_vr
end

function initialize_supply_function_equilibrium_outputs(
    inputs::AbstractInputs,
    run_time_options::RunTimeOptions,
)
    outputs = Outputs()

    if use_virtual_reservoirs(inputs)
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
            output_name = "virtual_reservoir_sfe_quantity",
            dimensions = ["period", "scenario", "sfe_iteration", "sfe_curve_segment"],
            unit = "MWh",
            labels = vr_labels,
            run_time_options,
        )
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "virtual_reservoir_sfe_price",
            dimensions = ["period", "scenario", "sfe_iteration", "sfe_curve_segment"],
            unit = "\$/MWh",
            labels = vr_labels,
            run_time_options,
        )
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "virtual_reservoir_sfe_slope",
            dimensions = ["period", "scenario", "sfe_iteration", "sfe_curve_segment"],
            unit = "\$/MWh2",
            labels = vr_labels,
            run_time_options,
        )

        # These are the bids that reach the clearing problem, as opposed to the diagnostic curves above.
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "virtual_reservoir_sfe_energy_bid",
            dimensions = ["period", "scenario", "bid_segment"],
            unit = "MWh",
            labels = vr_labels,
            run_time_options,
        )
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "virtual_reservoir_sfe_price_bid",
            dimensions = ["period", "scenario", "bid_segment"],
            unit = "\$/MWh",
            labels = vr_labels,
            run_time_options,
        )
    end

    if any_elements(inputs, BiddingGroup) && has_any_simple_bids(inputs)
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
            output_name = "bidding_group_sfe_quantity",
            dimensions = ["period", "scenario", "subperiod", "sfe_iteration", "sfe_curve_segment"],
            unit = "MWh",
            labels = bg_labels,
            run_time_options,
        )
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "bidding_group_sfe_price",
            dimensions = ["period", "scenario", "subperiod", "sfe_iteration", "sfe_curve_segment"],
            unit = "\$/MWh",
            labels = bg_labels,
            run_time_options,
        )
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "bidding_group_sfe_slope",
            dimensions = ["period", "scenario", "subperiod", "sfe_iteration", "sfe_curve_segment"],
            unit = "\$/MWh2",
            labels = bg_labels,
            run_time_options,
        )

        # These are the bids that reach the clearing problem, as opposed to the diagnostic curves above.
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "bidding_group_sfe_energy_bid",
            dimensions = ["period", "scenario", "subperiod", "bid_segment"],
            unit = "MWh",
            labels = bg_labels,
            run_time_options,
        )
        initialize!(
            QuiverOutput,
            outputs;
            inputs,
            output_name = "bidding_group_sfe_price_bid",
            dimensions = ["period", "scenario", "subperiod", "bid_segment"],
            unit = "\$/MWh",
            labels = bg_labels,
            run_time_options,
        )
    end

    return outputs
end

function write_supply_function_equilibrium_vr_outputs(
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
        "virtual_reservoir_sfe_quantity",
        quantity,
        period,
        scenario,
    )

    write_nash_equilibrium_vr_output!(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_sfe_price",
        price,
        period,
        scenario,
    )

    write_nash_equilibrium_vr_output!(
        outputs,
        inputs,
        run_time_options,
        "virtual_reservoir_sfe_slope",
        slope,
        period,
        scenario,
    )

    return nothing
end

function write_supply_function_equilibrium_bg_outputs(
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
        "bidding_group_sfe_quantity",
        reshaped_quantity,
        period,
        scenario,
    )

    write_nash_equilibrium_bg_output!(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_sfe_price",
        reshaped_price,
        period,
        scenario,
    )

    write_nash_equilibrium_bg_output!(
        outputs,
        inputs,
        run_time_options,
        "bidding_group_sfe_slope",
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
