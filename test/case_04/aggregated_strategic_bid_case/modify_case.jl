#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = IARA.load_study(PATH; read_only = false)

# Update base case elements
IARA.update_configuration!(db;
    aggregate_buses_for_strategic_bidding = IARA.Configurations_BusesAggregationForStrategicBidding.AGGREGATE,
)
IARA.update_asset_owner!(db, "asset_owner_1";
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.update_asset_owner!(db, "asset_owner_2";
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)

# Add elements
IARA.add_asset_owner!(db;
    label = "asset_owner_3",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)

IARA.add_bidding_group!(db;
    label = "bg_3",
    assetowner_id = "asset_owner_3",
)
number_of_bidding_groups += 1

IARA.add_thermal_unit!(db;
    label = "ter_ab_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 75.0,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
    biddinggroup_id = "bg_1",
)

IARA.add_thermal_unit!(db;
    label = "ter_ab_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 85.0,
    ),
    has_commitment = 0,
    bus_id = "bus_2",
    biddinggroup_id = "bg_1",
)

IARA.add_thermal_unit!(db;
    label = "ter_ab_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 95.0,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
    biddinggroup_id = "bg_2",
)

IARA.add_thermal_unit!(db;
    label = "ter_ab_4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 60.0,
    ),
    has_commitment = 0,
    bus_id = "bus_2",
    biddinggroup_id = "bg_2",
)

# Create and link CSV files
# -------------------------
# Demand
new_demand = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods) .+ 9.9 / max_demand
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    new_demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

# Offers
new_quantity_bid =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
new_quantity_bid[1:(number_of_bidding_groups-1), :, :, :, :, :] .= quantity_bid
new_quantity_bid[number_of_bidding_groups, :, :, :, :, :] .= quantity_bid[1, :, :, :, :, :]
IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_bid"),
    new_quantity_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2", "bg_3"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "MWh",
)

new_price_bid =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
new_price_bid[1:(number_of_bidding_groups-1), :, :, :, :, :] .= price_bid
new_price_bid[number_of_bidding_groups, :, :, :, :, :] .= price_bid[1, :, :, :, :, :]
IARA.write_bids_time_series_file(
    joinpath(PATH, "price_bid"),
    new_price_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2", "bg_3"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.close_study!(db)
