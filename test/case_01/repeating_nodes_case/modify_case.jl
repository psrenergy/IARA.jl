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
    policy_graph_type = IARA.Configurations_PolicyGraphType.CYCLIC_WITH_SEASON_ROOT,
    expected_number_of_repeats_per_node = [2.0 for _ in 1:number_of_periods],
)

# This case is built on top of the cyclic graph case

IARA.close_study!(db)
