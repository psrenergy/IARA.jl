#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

using Dates
using DataFrames

IARA.update_configuration!(
    db;
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    settlement_type = IARA.Configurations_SettlementType.DUAL,
)

IARA.update_thermal_unit_relation!(
    db,
    "Termica 1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "Azul",
)

IARA.update_thermal_unit_relation!(
    db,
    "Termica 2";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "Roxo",
)

IARA.update_thermal_unit_relation!(
    db,
    "Termica 3";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "Verde",
)

IARA.update_thermal_unit_relation!(
    db,
    "Termica 4";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "Amarelo",
)

IARA.update_thermal_unit_relation!(
    db,
    "Termica 5";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "Vermelho",
)

price_offer[1, :, :, :, :, :] .= 80.0
price_offer[2, :, :, :, :, :] .= 60.0
price_offer[3, :, :, :, :, :] .= 75.0
price_offer[4, :, :, :, :, :] .= 40.0
price_offer[5, :, :, :, :, :] .= 45.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Vermelho", "Verde", "Amarelo", "Azul", "Roxo"],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2024-01-01T00:00:00",
    unit = "\$/MWh",
)
