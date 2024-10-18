
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
    run_mode = IARA.Configurations_RunMode.HEURISTIC_BID,
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
    bid_type = IARA.BiddingGroup_BidType.MARKUP_HEURISTIC,
    risk_factor = [0.1],
    segment_fraction = [1.0],
    simple_bid_max_segments = 1,
)
IARA.add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_2",
    bid_type = IARA.BiddingGroup_BidType.MARKUP_HEURISTIC,
    risk_factor = [0.2, 0.3],
    segment_fraction = [0.4, 0.6],
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

# Create CSV files
# ----------------
# We need to create this file manually instead of copying it from 
# a CENTRALIZED_OPERATION problem because marginal cost outputs are degenerate
hydro_opportunity_cost = zeros(1, number_of_blocks, number_of_scenarios, number_of_stages)
hydro_opportunity_cost[:, :, 1:2, 1] .+= 0.375
hydro_opportunity_cost[:, :, 3, 1] .+= 1.0
hydro_opportunity_cost[:, :, 4, 1] .+= 31.625
hydro_opportunity_cost[:, :, 1, 2] .+= 0.0
hydro_opportunity_cost[:, :, 2, 2] .+= 0.25
hydro_opportunity_cost[:, :, 3, 2] .+= 1.0
hydro_opportunity_cost[:, :, 4, 2] .+= 125.25
hydro_opportunity_cost[:, :, 1:2, 3] .+= 0.0
hydro_opportunity_cost[:, :, 3, 3] .+= 1.0
hydro_opportunity_cost[:, :, 4, 3] .+= 500.0
IARA.write_timeseries_file(
    joinpath(PATH, "hydro_opportunity_cost"),
    hydro_opportunity_cost;
    dimensions = ["stage", "scenario", "block"],
    labels = ["hyd_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.close_study!(db)
