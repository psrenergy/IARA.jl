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
    purchase_bids_for_virtual_reservoir_heuristic_bid = IARA.Configurations_ConsiderPurchaseBidsForVirtualReservoirHeuristicBid.DO_NOT_CONSIDER,
)

IARA.close_study!(db)
