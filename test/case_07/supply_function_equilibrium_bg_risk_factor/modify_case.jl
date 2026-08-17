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

# Every bidding group in the supply function equilibrium cases is created with a zero risk factor, so the exogenous
# markup is zero by construction and those cases cannot tell whether the curves entering the equilibrium carry it.
# Here the risk factors are nonzero, so the equilibrium must ingest the no-markup prices instead of double-marking them.
for bg in 1:8
    IARA.update_bidding_group_vectors!(
        db,
        "thermal_bg_$(bg)";
        risk_factor = [0.3],
    )
end

IARA.close_study!(db)
