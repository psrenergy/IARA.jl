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

IARA.delete_asset_owner!(db, "asset_owner_2")
IARA.delete_virtual_reservoir!(db, "reservoir_1")

IARA.add_asset_owner!(db;
    label = "asset_owner_2",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
    purchase_discount_rate = [0.1, 0.2, 0.5],
)

IARA.add_virtual_reservoir!(db;
    label = "reservoir_1",
    assetowner_id = ["asset_owner_1", "asset_owner_2"],
    inflow_allocation = [0.5, 0.5],
    hydrounit_id = ["hydro_1", "hydro_2"],
)

IARA.close_study!(db)
