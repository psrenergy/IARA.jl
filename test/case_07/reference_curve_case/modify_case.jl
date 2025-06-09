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
    reference_curve_demand_multipliers = [0.5, 1.0, 1.5],
)

output_path_min_cost = joinpath(PATH, "..", "min_cost_case", "outputs")
if !isdir(output_path_min_cost)
    IARA.train_min_cost(joinpath(PATH, "..", "min_cost_case"); plot_outputs = false)
end

# Define files to copy (base_name, extension)
files_to_copy = [
    "cuts",
]

# Copy all files from base_case/outputs to current directory
files_filter = x -> any(occursin.(files_to_copy, x))
Main.copy_files(output_path_min_cost, PATH, files_filter)

IARA.link_time_series_to_file(
    db,
    "Configuration";
    fcf_cuts = "cuts.json",
)

IARA.close_study!(db)
