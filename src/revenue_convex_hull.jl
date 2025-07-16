#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

@kwdef mutable struct Point
    x::Float64
    y::Float64
end

function pricemaker_revenue(
    quantity_bids::Vector{Float64},
    price_bids::Vector{Float64},
    demand_unit::Float64,
    deficit_cost::Float64;
    contracts_quantity::Vector{Float64} = Float64[],
    contracts_price::Vector{Float64} = Float64[],
)
    # Add deficit thermal unit to cover demand
    append!(quantity_bids, demand_unit)
    append!(price_bids, deficit_cost)
    # Calculate revenue
    has_contracts = length(contracts_quantity) > 0 && sum(contracts_quantity) > 0.0
    merit_order = sortperm(price_bids)
    sums = cumsum(quantity_bids[merit_order])
    duals = price_bids[reverse!(merit_order)]
    if has_contracts
        fixed_contract_revenue = dot(contracts_price, contracts_quantity)
        total_contracted_quantity = sum(contracts_quantity)
    end
    points = Point[]
    N = length(duals)
    @assert sums[end] > demand_unit
    i = 0
    first = true
    for e in Iterators.reverse(sums)
        bid_energy = demand_unit - e
        if bid_energy > 0
            # because sum(quantity_bids) > demand_unit, sums[end] > demand_unit
            # hence i == 0 will never reach here
            if has_contracts
                if first
                    push!(points, Point(0.0, fixed_contract_revenue - total_contracted_quantity * duals[i]))
                    first = false
                end
                revenue = fixed_contract_revenue - total_contracted_quantity * duals[i] + bid_energy * duals[i]
                push!(points, Point(bid_energy, revenue))
                if i < N
                    revenue =
                        fixed_contract_revenue - total_contracted_quantity * duals[i+1] + bid_energy * duals[i+1]
                    push!(points, Point(bid_energy, revenue))
                end
            else
                if first
                    push!(points, Point(0.0, 0.0))
                    first = false
                end
                revenue = bid_energy * duals[i]
                push!(points, Point(bid_energy, revenue))
            end
        end
        i += 1
    end
    if has_contracts
        if first
            push!(points, Point(0.0, fixed_contract_revenue - total_contracted_quantity * duals[i]))
            first = false
        end
        push!(
            points,
            Point(demand_unit, fixed_contract_revenue - total_contracted_quantity * duals[i] + demand_unit * duals[i]),
        )
        push!(points, Point(demand_unit, fixed_contract_revenue))
    else
        if first
            push!(points, Point(0.0, 0.0))
            first = false
        end
        push!(points, Point(demand_unit, demand_unit * duals[i]))
        push!(points, Point(demand_unit, 0.0))
    end
    return points
end

# https://en.wikibooks.org/wiki/Algorithm_Implementation/Geometry/Convex_hull/Monotone_chain
function cross(o::Point, a::Point, b::Point)
    return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
end

function upper_convex_hull(points::Vector{Point})
    if length(points) <= 1
        return points
    end
    upper = Point[]
    for p in Iterators.reverse(points)
        while length(upper) >= 2 && cross(upper[end-1], upper[end], p) <= 0.0
            pop!(upper)
        end
        push!(upper, p)
    end
    return upper
end

function update_convex_hull_cache!(inputs, run_time_options::RunTimeOptions)
    buses = index_of_elements(inputs, Bus)
    demands = index_of_elements(inputs, DemandUnit; filters = [is_existing])
    bidding_groups = index_of_elements(inputs, BiddingGroup)
    blks = subperiods(inputs)
    quantity_bids_ts = time_series_quantity_bid(inputs)
    price_bids_ts = time_series_price_bid(inputs)
    demand_ts = time_series_demand(inputs, run_time_options)

    if aggregate_buses_for_strategic_bidding(inputs)
        inputs.collections.asset_owner.revenue_convex_hull =
            Array{Vector{Point}, 2}(undef, 1, number_of_subperiods(inputs))
        for blk in blks
            # Get data for current subperiod
            # The maximum number of segments is hard-coded to 1
            quantity_bids =
                [
                    quantity_bids_ts[bg, bus, 1, blk]
                    for bus in buses, bg in bidding_groups if
                    bidding_group_asset_owner_index(inputs, bg) != run_time_options.asset_owner_index
                ]
            # The maximum number of segments is hard-coded to 1
            price_bids =
                [
                    price_bids_ts[bg, bus, 1, blk]
                    for bus in buses, bg in bidding_groups if
                    bidding_group_asset_owner_index(inputs, bg) != run_time_options.asset_owner_index
                ]
            demand =
                sum(
                    demand_mw_to_gwh(
                        inputs,
                        demand_ts[d, blk],
                        d,
                        blk,
                    ) for d in demands;
                    init = 0.0,
                ) / MW_to_GW()
            # Update revenue convex hull cache
            points = pricemaker_revenue(
                quantity_bids,
                price_bids,
                demand,
                demand_deficit_cost(inputs),
            )
            inputs.collections.asset_owner.revenue_convex_hull[1, blk] = upper_convex_hull(points)
        end
    else
        num_buses = number_of_elements(inputs, Bus)

        inputs.collections.asset_owner.revenue_convex_hull =
            Array{Vector{Point}, 2}(undef, num_buses, number_of_subperiods(inputs))
        for blk in blks, bus in buses
            # Get data for current bus and subperiod
            # The maximum number of segments is hard-coded to 1
            quantity_bids = [
                quantity_bids_ts[bg, bus, 1, blk]
                for
                bg in bidding_groups if
                bidding_group_asset_owner_index(inputs, bg) != run_time_options.asset_owner_index
            ]
            # The maximum number of segments is hard-coded to 1
            price_bids = [
                price_bids_ts[bg, bus, 1, blk]
                for
                bg in bidding_groups if
                bidding_group_asset_owner_index(inputs, bg) != run_time_options.asset_owner_index
            ]
            demand =
                sum(
                    demand_mw_to_gwh(
                        inputs,
                        demand_ts[d, blk],
                        d,
                        blk,
                    ) for d in demands if demand_unit_bus_index(inputs, d) == bus;
                    init = 0.0,
                ) / MW_to_GW()
            # Update revenue convex hull cache
            points = pricemaker_revenue(
                quantity_bids,
                price_bids,
                demand,
                demand_deficit_cost(inputs),
            )
            inputs.collections.asset_owner.revenue_convex_hull[bus, blk] = upper_convex_hull(points)
        end
    end
    return nothing
end
