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

IARA.train_min_cost(PATH; plot_outputs = false, delete_output_folder_before_execution = true)
mv(joinpath(PATH, "outputs", "cuts.json"), joinpath(PATH, "cuts.json"), force = true)

IARA.link_time_series_to_file(
    db,
    "Configuration";
    fcf_cuts = "cuts.json",
)

IARA.update_configuration!(db;
    reference_curve_demand_multipliers = [0.5, 1.0, 1.5],
)

IARA.close_study!(db)