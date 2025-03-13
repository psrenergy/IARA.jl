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

IARA.update_bidding_group_relation!(
    db,
    "a";
    collection = "AssetOwner",
    relation_type = "id",
    related_label = "Agente Azul",
)

IARA.update_bidding_group_relation!(
    db,
    "b";
    collection = "AssetOwner",
    relation_type = "id",
    related_label = "Agente Roxo",
)

IARA.update_bidding_group_relation!(
    db,
    "c";
    collection = "AssetOwner",
    relation_type = "id",
    related_label = "Agente Verde",
)

IARA.update_bidding_group_relation!(
    db,
    "d";
    collection = "AssetOwner",
    relation_type = "id",
    related_label = "Agente Amarelo",
)

IARA.update_bidding_group_relation!(
    db,
    "e";
    collection = "AssetOwner",
    relation_type = "id",
    related_label = "Agente Vermelho",
)
