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

IARA.update_configuration!(db;
    demand_deficit_cost = 600.0,
    supply_function_equilibrium_max_cost_multiplier = 1.25,
)

# Asset owners
IARA.add_asset_owner!(db;
    label = "thermal_asset_owner_1",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "thermal_asset_owner_2",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "thermal_asset_owner_3",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "thermal_asset_owner_4",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "thermal_asset_owner_5",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "thermal_asset_owner_6",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "thermal_asset_owner_7",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "thermal_asset_owner_8",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)

# Bidding groups
IARA.add_bidding_group!(db;
    label = "thermal_bg_1",
    assetowner_id = "thermal_asset_owner_1",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_2",
    assetowner_id = "thermal_asset_owner_2",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_3",
    assetowner_id = "thermal_asset_owner_3",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_4",
    assetowner_id = "thermal_asset_owner_4",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_5",
    assetowner_id = "thermal_asset_owner_5",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_6",
    assetowner_id = "thermal_asset_owner_6",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_7",
    assetowner_id = "thermal_asset_owner_7",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_8",
    assetowner_id = "thermal_asset_owner_8",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)

# Thermal units
IARA.add_thermal_unit!(
    db;
    label = "thermal_1a",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.02],
        om_cost = [3.0],
    ),
    biddinggroup_id = "thermal_bg_1",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_1b",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.08],
        om_cost = [5.0],
    ),
    biddinggroup_id = "thermal_bg_1",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_2a",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.02],
        om_cost = [3.0],
    ),
    biddinggroup_id = "thermal_bg_2",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_2b",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.08],
        om_cost = [5.0],
    ),
    biddinggroup_id = "thermal_bg_2",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_3a",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.02],
        om_cost = [3.0],
    ),
    biddinggroup_id = "thermal_bg_3",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_3b",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.08],
        om_cost = [5.0],
    ),
    biddinggroup_id = "thermal_bg_3",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_4a",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.04],
        om_cost = [40.0],
    ),
    biddinggroup_id = "thermal_bg_4",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_4b",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.16],
        om_cost = [60.0],
    ),
    biddinggroup_id = "thermal_bg_4",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_5a",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.04],
        om_cost = [40.0],
    ),
    biddinggroup_id = "thermal_bg_5",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_5b",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.16],
        om_cost = [60.0],
    ),
    biddinggroup_id = "thermal_bg_5",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_6a",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.04],
        om_cost = [40.0],
    ),
    biddinggroup_id = "thermal_bg_6",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_6b",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.16],
        om_cost = [60.0],
    ),
    biddinggroup_id = "thermal_bg_6",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_7a",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.02],
        om_cost = [90.0],
    ),
    biddinggroup_id = "thermal_bg_7",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_7b",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.08],
        om_cost = [110.0],
    ),
    biddinggroup_id = "thermal_bg_7",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_8a",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.02],
        om_cost = [90.0],
    ),
    biddinggroup_id = "thermal_bg_8",
    bus_id = "bus_1",
)
IARA.add_thermal_unit!(
    db;
    label = "thermal_8b",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [0.08],
        om_cost = [110.0],
    ),
    biddinggroup_id = "thermal_bg_8",
    bus_id = "bus_1",
)

IARA.close_study!(db)
