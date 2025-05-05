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

IARA.update_configuration!(
    db;
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    settlement_type = IARA.Configurations_SettlementType.EX_ANTE,
)

IARA.add_asset_owner!(db;
    label = "asset_owner_1",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)

IARA.add_asset_owner!(db;
    label = "asset_owner_2",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)

IARA.add_bidding_group!(db;
    label = "bg_1",
    assetowner_id = "asset_owner_1",
)

IARA.add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_2",
)

number_of_bidding_groups = 2
maximum_number_of_bidding_segments = 1

IARA.update_thermal_unit_relation!(db, "thermal_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)

IARA.update_demand_unit_relation!(db, "flex_dem_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_2",
)

number_of_buses = 1
nominal_demand = demand * max_demand
max_thermal_generation = 6.0

quantity_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
quantity_offer[1, 1, 1, :, :, :] .= max_thermal_generation
quantity_offer[2, 1, 1, :, :, :] = -nominal_demand

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods, maximum_number_of_bidding_segments],
    initial_date = "2024-01-01",
    unit = "MWh",
)

price_offer = zeros(
    number_of_bidding_groups,
    number_of_buses,
    maximum_number_of_bidding_segments,
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)
price_offer[1, 1, 1, :, :, :] .= 100
price_offer[2, 1, 1, :, 1, :] .= 90
price_offer[2, 1, 1, :, 2, :] .= 110

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods, maximum_number_of_bidding_segments],
    initial_date = "2024-01-01",
    unit = "\$/MWh",
)

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer = "quantity_offer",
    price_offer = "price_offer",
)
