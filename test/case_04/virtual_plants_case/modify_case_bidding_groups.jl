
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
IARA.update_bidding_group_relation!(
    db,
    "bg_2";
    collection = "AssetOwner",
    relation_type = "id",
    related_label = "asset_owner_1",
)

IARA.close_study!(db)
