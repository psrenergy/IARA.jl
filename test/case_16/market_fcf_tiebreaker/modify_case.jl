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

PATH_BASE_CASE = joinpath(PATH, "..", "base_case")

# Define files to copy (base_name, extension)
files_to_copy = [
    "cuts",
    "hydro_generation",
    "hydro_opportunity_cost",
    "hydro_generation",
    "hydro_opportunity_cost",
]

# Copy all files from base_case/outputs to current directory
files_filter = x -> any(occursin.(files_to_copy, x))
outputs_base_case = joinpath(PATH_BASE_CASE, "outputs")
Main.copy_files(outputs_base_case, PATH, files_filter)

IARA.link_time_series_to_file(
    db,
    "Configuration";
    fcf_cuts = "cuts.json",
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
maximum_number_of_bidding_segments = 2

IARA.update_thermal_unit_relation!(db, "ter_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)

IARA.update_renewable_unit_relation!(db, "gnd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)

IARA.update_hydro_unit_relation!(db, "hyd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_2",
)

IARA.update_configuration!(
    db;
    market_clearing_tiebreaker_weight_for_om_costs = 1e-4,
    bid_processing = IARA.Configurations_BidProcessing.PARAMETERIZED_HEURISTIC_BIDS,
    bid_price_validation = IARA.Configurations_BidPriceValidation.DO_NOT_VALIDATE,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    network_representation_ex_ante_commercial = IARA.Configurations_NetworkRepresentation.ZONAL,
    network_representation_ex_post_commercial = IARA.Configurations_NetworkRepresentation.ZONAL,
)

IARA.close_study!(db)
