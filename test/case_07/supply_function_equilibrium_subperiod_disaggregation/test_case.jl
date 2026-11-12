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

# Unit tests for the subperiod shape that splits a bidding group's subperiod-aggregated equilibrium curve back into
# subperiods. Every stretch of the curve must be split like the original bids at the same cumulative quantity, in
# ascending price order, rather than evenly.

module TestCase07SupplyFunctionEquilibriumSubperiodDisaggregation

using Test
using IARA

# Aggregate the bids over subperiods as `treat_bidding_group_data` does, then build their subperiod shape. Quantities
# are indexed by (segment, subperiod).
function subperiod_shape(
    quantity::Matrix{Float64},
    price::Vector{Float64};
    duration_share::Vector{Float64} = fill(1 / size(quantity, 2), size(quantity, 2)),
)
    aggregated_quantity = vec(sum(quantity; dims = 2))
    return IARA.bidding_group_subperiod_shape(quantity, aggregated_quantity, price, duration_share)
end

@testset "Supply function equilibrium subperiod disaggregation" begin
    # A flat thermal unit, listed first but priced higher, and a renewable unit that only produces from subperiod 2 on.
    quantity = [
        10.0 10.0 10.0 10.0
        0.0 10.0 20.0 30.0
    ]
    price = [50.0, 1.0]
    renewable_share = [0.0, 1 / 6, 2 / 6, 3 / 6]
    thermal_share = [0.25, 0.25, 0.25, 0.25]
    shape = subperiod_shape(quantity, price)

    @testset "Segments follow ascending price order" begin
        # The renewable unit's 60 MWh come first in the merit order, and the thermal unit's 40 MWh after them.
        @test shape.cumulative_quantity ≈ [60.0, 100.0]
        @test shape.subperiod_share ≈ vcat(renewable_share', thermal_share')
    end

    @testset "The whole curve splits back into the original bids" begin
        @test IARA.disaggregate_quantity_in_subperiods(shape, 0.0, 100.0) ≈ vec(sum(quantity; dims = 1))
    end

    @testset "A stretch within a segment follows that segment's shape" begin
        @test IARA.disaggregate_quantity_in_subperiods(shape, 12.0, 30.0) ≈ 18.0 .* renewable_share
        @test IARA.disaggregate_quantity_in_subperiods(shape, 70.0, 90.0) ≈ 20.0 .* thermal_share
    end

    @testset "A stretch across segments splits each part like its own segment" begin
        # [30, 60] lies on the renewable unit's segment and [60, 80] on the thermal unit's.
        @test IARA.disaggregate_quantity_in_subperiods(shape, 30.0, 80.0) ≈
              30.0 .* renewable_share .+ 20.0 .* thermal_share
    end

    @testset "Consecutive stretches add up to the stretch they cover" begin
        points = [0.0, 7.0, 45.0, 60.0, 61.5, 88.0, 100.0]
        pieces = [IARA.disaggregate_quantity_in_subperiods(shape, points[i], points[i+1]) for i in 1:length(points)-1]
        @test sum(pieces) ≈ IARA.disaggregate_quantity_in_subperiods(shape, 0.0, 100.0)
        @test all(iszero, IARA.disaggregate_quantity_in_subperiods(shape, 45.0, 45.0))
    end

    @testset "The first and last segments extend past the ends of the curve" begin
        # Rounding can leave the equilibrium curve a hair past the reference curve, and that excess must not be lost.
        @test IARA.disaggregate_quantity_in_subperiods(shape, 100.0, 101.0) ≈ thermal_share
        @test IARA.disaggregate_quantity_in_subperiods(shape, -1.0, 0.0) ≈ renewable_share
    end

    @testset "Subperiod share at a quantity" begin
        @test IARA.subperiod_share_at_quantity(shape, 30.0) ≈ renewable_share
        # A boundary between two segments belongs to the lower one.
        @test IARA.subperiod_share_at_quantity(shape, 60.0) ≈ renewable_share
        @test IARA.subperiod_share_at_quantity(shape, 60.5) ≈ thermal_share
        @test IARA.subperiod_share_at_quantity(shape, -1.0) ≈ renewable_share
        @test IARA.subperiod_share_at_quantity(shape, 150.0) ≈ thermal_share
    end

    @testset "Segments that share a price are blended" begin
        # The equilibrium cannot tell two units with the same price apart, so every part of their joint stretch follows
        # their joint shape, whatever the order in which they are listed.
        same_price_quantity = [
            10.0 0.0 0.0 0.0
            0.0 0.0 0.0 30.0
        ]
        for order in ([1, 2], [2, 1])
            same_price_shape = subperiod_shape(same_price_quantity[order, :], [5.0, 5.0])
            @test same_price_shape.cumulative_quantity ≈ [40.0]
            @test IARA.disaggregate_quantity_in_subperiods(same_price_shape, 0.0, 20.0) ≈ [5.0, 0.0, 0.0, 15.0]
        end
    end

    @testset "Empty segments are dropped" begin
        # The zero padding of the bid arrays must not add a segment to the shape.
        padded_shape = subperiod_shape(vcat(quantity, zeros(2, 4)), vcat(price, [0.0, 0.0]))
        @test padded_shape.cumulative_quantity ≈ shape.cumulative_quantity
        @test padded_shape.subperiod_share ≈ shape.subperiod_share
    end

    @testset "Bids with constant capacity keep the split by duration" begin
        # A unit with constant capacity offers energy in proportion to each subperiod's duration, so following its
        # shape is the same as splitting by duration.
        duration = [100.0, 200.0, 300.0, 400.0]
        duration_share = duration ./ sum(duration)
        flat_quantity = vcat(2.0 .* duration', 5.0 .* duration')
        flat_shape = subperiod_shape(flat_quantity, [10.0, 20.0]; duration_share)
        @test IARA.disaggregate_quantity_in_subperiods(flat_shape, 300.0, 4200.0) ≈ 3900.0 .* duration_share
    end

    @testset "An agent that offers nothing splits by duration" begin
        duration_share = [0.1, 0.2, 0.3, 0.4]
        empty_shape = subperiod_shape(zeros(3, 4), zeros(3); duration_share)
        @test empty_shape.cumulative_quantity == [0.0]
        @test IARA.subperiod_share_at_quantity(empty_shape, 0.0) ≈ duration_share
        @test all(iszero, IARA.disaggregate_quantity_in_subperiods(empty_shape, 0.0, 0.0))
    end
end

end
