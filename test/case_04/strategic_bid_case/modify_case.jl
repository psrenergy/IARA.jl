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
    run_mode = IARA.Configurations_RunMode.STRATEGIC_BID,
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
    simple_bid_max_segments = 1,
)
number_of_bidding_groups += 1

IARA.add_demand!(db;
    label = "dem_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.Demand_Existence.EXISTS)],
    ),
    bus_id = "bus_2",
)

IARA.add_thermal_plant!(db;
    label = "ter_sb_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalPlant_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 75.0 / 1e3,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
    biddinggroup_id = "bg_1",
)

IARA.add_thermal_plant!(db;
    label = "ter_sb_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalPlant_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 85.0 / 1e3,
    ),
    has_commitment = 0,
    bus_id = "bus_2",
    biddinggroup_id = "bg_1",
)

IARA.add_thermal_plant!(db;
    label = "ter_sb_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalPlant_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 95.0 / 1e3,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
    biddinggroup_id = "bg_2",
)

IARA.add_thermal_plant!(db;
    label = "ter_sb_4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalPlant_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 105.0 / 1e3,
    ),
    has_commitment = 0,
    bus_id = "bus_2",
    biddinggroup_id = "bg_2",
)

# Create and link CSV files
# -------------------------
# Demand
new_demand = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages) .+ 9.9 * MW_to_GWh
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    new_demand;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_1", "dem_2"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

# Offers
new_quantity_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_blocks,
        number_of_scenarios,
        number_of_stages,
    )
new_quantity_offer[1:(number_of_bidding_groups-1), :, :, :, :, :] .= quantity_offer
new_quantity_offer[number_of_bidding_groups, :, :, :, :, :] .= quantity_offer[1, :, :, :, :, :]
IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    new_quantity_offer;
    dimensions = ["stage", "scenario", "block", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2", "bg_3"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "stage",
    dimension_size = [
        number_of_stages,
        number_of_scenarios,
        number_of_blocks,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "MWh",
)

new_price_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_blocks,
        number_of_scenarios,
        number_of_stages,
    )
new_price_offer[1:(number_of_bidding_groups-1), :, :, :, :, :] .= price_offer
new_price_offer[number_of_bidding_groups, :, :, :, :, :] .= price_offer[1, :, :, :, :, :]
IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    new_price_offer;
    dimensions = ["stage", "scenario", "block", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2", "bg_3"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "stage",
    dimension_size = [
        number_of_stages,
        number_of_scenarios,
        number_of_blocks,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.close_study!(db)
