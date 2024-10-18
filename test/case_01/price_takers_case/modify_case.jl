
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
    run_mode = IARA.Configurations_RunMode.PRICE_TAKER_BID,
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
    bid_type = IARA.BiddingGroup_BidType.OPTIMIZE,
    simple_bid_max_segments = 1,
)
IARA.add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_2",
    bid_type = IARA.BiddingGroup_BidType.OPTIMIZE,
    simple_bid_max_segments = 1,
)

IARA.update_hydro_plant_relation!(db, "hyd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)
IARA.update_thermal_plant_relation!(db, "ter_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_2",
)
IARA.update_renewable_plant_relation!(db, "gnd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)

# Modify inflow series
new_inflow = zeros(1, number_of_blocks, number_of_scenarios, number_of_stages)
for scenario in 1:number_of_scenarios
    new_inflow[:, :, scenario, :] .= inflow[:, :, end, :]
end
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    new_inflow;
    dimensions = ["stage", "scenario", "block"],
    labels = ["hyd_1_gauging_station"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

# Spot price time series
spot_price = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages)
for stage in 1:number_of_stages, scenario in 1:number_of_scenarios
    spot_price[:, :, scenario, stage] .= (scenario + stage + 0.5) / 5
end
IARA.write_timeseries_file(
    joinpath(PATH, "load_marginal_cost"),
    spot_price;
    dimensions = ["stage", "scenario", "block"],
    labels = ["bus_1", "bus_2"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.close_study!(db)
