#############################################################################
#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

# Unit tests for the conversion of a supply function equilibrium curve back into incremental bids. The conversion must
# invert `quantity_points_from_segments` and `reverse_bid_order_and_add_point` exactly, including for purchase bids,
# whose quantities are negative.

module TestCase07SupplyFunctionEquilibriumBidConversion

using Test
using IARA

# Apply the same treatment that `treat_reference_curve_data` and `treat_bidding_group_data` apply before the
# equilibrium iteration, so the conversion is tested against the real forward transformation.
function stored_curve(
    incremental_quantity::Vector{Float64},
    price::Vector{Float64},
    deficit_cost::Float64,
    extra_bid_quantity::Float64,
)
    cumulative_quantity = IARA.quantity_points_from_segments(incremental_quantity)
    quantity = vcat(cumulative_quantity[end] + extra_bid_quantity, reverse(cumulative_quantity))
    return quantity, vcat(deficit_cost, reverse(price))
end

function round_trip(
    incremental_quantity::Vector{Float64},
    price::Vector{Float64},
    number_of_bid_segments::Int;
    deficit_cost::Float64 = 600.0,
    extra_bid_quantity::Float64 = 1.0,
)
    quantity, stored_price = stored_curve(incremental_quantity, price, deficit_cost, extra_bid_quantity)
    return IARA.supply_function_equilibrium_bids_from_curve(quantity, stored_price, number_of_bid_segments)
end

@testset "Supply function equilibrium bid conversion" begin
    @testset "Sell bids" begin
        incremental_quantity = [10.0, 5.0, 2.5]
        price = [30.0, 60.0, 90.0]
        quantity_bid, price_bid = round_trip(incremental_quantity, price, 6)

        @test quantity_bid[1:3] ≈ incremental_quantity
        @test price_bid[1:3] ≈ price
        # The width is fixed by the analytic bound, so the unused tail must be zeroed rather than left with the
        # synthetic deficit-cost point.
        @test all(iszero, quantity_bid[4:6])
        @test all(iszero, price_bid[4:6])
    end

    @testset "Purchase bids" begin
        incremental_quantity = [-8.0, -4.0]
        price = [20.0, 45.0]
        quantity_bid, price_bid = round_trip(incremental_quantity, price, 5)

        @test quantity_bid[1:2] ≈ incremental_quantity
        @test price_bid[1:2] ≈ price
        @test all(quantity_bid[1:2] .< 0.0)
    end

    @testset "Sell and purchase bids together" begin
        incremental_quantity = [12.0, 3.0, -5.0]
        price = [25.0, 70.0, 15.0]
        quantity_bid, price_bid = round_trip(incremental_quantity, price, 4)

        @test quantity_bid[1:3] ≈ incremental_quantity
        @test price_bid[1:3] ≈ price
    end

    @testset "Single segment" begin
        quantity_bid, price_bid = round_trip([7.0], [50.0], 3)

        @test quantity_bid[1] ≈ 7.0
        @test price_bid[1] ≈ 50.0
        @test all(iszero, quantity_bid[2:3])
    end

    @testset "Exact width" begin
        incremental_quantity = [4.0, 6.0]
        price = [10.0, 20.0]
        quantity_bid, price_bid = round_trip(incremental_quantity, price, 2)

        @test quantity_bid ≈ incremental_quantity
        @test price_bid ≈ price
    end

    @testset "Curve wider than the bound errors" begin
        # A curve that does not fit the width the model was built for must fail loudly: silently truncating it would
        # drop bids, and writing past the end would corrupt the fixed-width arrays.
        quantity, price = stored_curve([1.0, 2.0, 3.0], [10.0, 20.0, 30.0], 600.0, 1.0)
        @test_throws ErrorException IARA.supply_function_equilibrium_bids_from_curve(quantity, price, 2)
    end

    @testset "Curve with only the synthetic point" begin
        # `reverse_bid_order_and_add_point` always prepends one point, so a curve of length one carries no real bid.
        quantity_bid, price_bid = IARA.supply_function_equilibrium_bids_from_curve([5.0], [600.0], 3)

        @test all(iszero, quantity_bid)
        @test all(iszero, price_bid)
    end
end

end
