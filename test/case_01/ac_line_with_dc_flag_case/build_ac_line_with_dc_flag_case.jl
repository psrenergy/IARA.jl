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

# Change the DC line to an AC line, modeled as a DC line

delete_element!(db, "DCLine", "dc_1")

add_branch!(db;
    label = "ac_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        capacity = [5.5],
        reactance = [0.5],
    ),
    bus_from = "bus_1",
    bus_to = "bus_2",
    line_model = IARA.Branch_LineModel.AC,
)

close_study!(db)
