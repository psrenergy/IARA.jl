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
    clearing_bid_source = IARA.Configurations_ClearingBidSource.HEURISTIC_BIDS,
    clearing_model_type_ex_ante_physical = IARA.Configurations_ClearingModelType.SKIP,
    clearing_model_type_ex_ante_commercial = IARA.Configurations_ClearingModelType.SKIP,
    clearing_model_type_ex_post_physical = IARA.Configurations_ClearingModelType.SKIP,
    clearing_model_type_ex_post_commercial = IARA.Configurations_ClearingModelType.SKIP,
)

IARA.close_study!(db)
