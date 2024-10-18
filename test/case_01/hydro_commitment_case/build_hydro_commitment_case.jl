#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = load_study(PATH; read_only = false)

update_hydro_plant!(db, "hyd_1"; has_commitment = 1)
update_hydro_plant_time_series_parameter!(
    db,
    "hyd_1",
    "min_generation",
    2.0;
    date_time = DateTime(0),
)
update_configuration!(db; use_binary_variables = 1)

close_study!(db)
