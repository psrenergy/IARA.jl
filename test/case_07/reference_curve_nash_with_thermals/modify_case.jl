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

IARA.add_asset_owner!(db;
    label = "asset_owner_5",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "asset_owner_6",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "asset_owner_7",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(db;
    label = "asset_owner_8",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)

IARA.add_bidding_group!(db;
    label = "thermal_bg_1",
    assetowner_id = "asset_owner_5",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_2",
    assetowner_id = "asset_owner_6",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_3",
    assetowner_id = "asset_owner_7",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)
IARA.add_bidding_group!(db;
    label = "thermal_bg_4",
    assetowner_id = "asset_owner_8",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)

IARA.add_thermal_unit!(
    db;
    label = "thermal_1a",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [100.0],
        om_cost = [100.0],
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
        max_generation = [100.0],
        om_cost = [150.0],
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
        max_generation = [100.0],
        om_cost = [200.0],
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
        max_generation = [100.0],
        om_cost = [250.0],
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
        max_generation = [100.0],
        om_cost = [300.0],
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
        max_generation = [100.0],
        om_cost = [350.0],
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
        max_generation = [100.0],
        om_cost = [400.0],
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
        max_generation = [100.0],
        om_cost = [450.0],
    ),
    biddinggroup_id = "thermal_bg_4",
    bus_id = "bus_1",
)

IARA.close_study!(db)
