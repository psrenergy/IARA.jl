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

IARA.update_hydro_unit!(db, "hyd_1"; has_commitment = IARA.HydroUnit_HasCommitment.HAS_COMMITMENT)
IARA.update_hydro_unit_time_series_parameter!(
    db,
    "hyd_1",
    "min_generation",
    2.0;
    date_time = DateTime(0),
)
IARA.update_configuration!(
    db;
    integer_variable_representation_mincost_type = IARA.Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY,
)

IARA.close_study!(db)
