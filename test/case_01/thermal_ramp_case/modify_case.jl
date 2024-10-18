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

IARA.add_thermal_plant!(db;
    label = "ter_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.ThermalPlant_Existence.EXISTS)],
        min_generation = [0.0],
        max_generation = [0.5],
        om_cost = [2.0],
    ),
    has_commitment = 0,
    max_ramp_up = 0.2 / 60,
    max_ramp_down = 0.2 / 60,
    generation_initial_condition = 0.0,
    bus_id = "bus_1",
)

IARA.close_study!(db)
