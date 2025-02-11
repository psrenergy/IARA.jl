#############################################################################
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

IARA.delete_element!(
    db,
    "HydroUnit",
    "Hydro Upstream",
)

IARA.delete_element!(
    db,
    "HydroUnit",
    "Hydro Downstream",
)

IARA.delete_element!(
    db,
    "BiddingGroup",
    "UpstreamA_01",
)

IARA.delete_element!(
    db,
    "BiddingGroup",
    "DownstreamA_01",
)

IARA.close_study!(db)
