#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

using Dates
using DataFrames

db = IARA.load_study(PATH; read_only = false)

PATH_BASE_CASE = joinpath(PATH, "..", "base_case")
path_base_case_cuts = joinpath(PATH_BASE_CASE, "outputs", "cuts.json")
path_cuts = joinpath(PATH, "cuts.json")

cp(path_base_case_cuts, path_cuts; force = true)

IARA.link_time_series_to_file(
    db,
    "Configuration";
    fcf_cuts = "cuts.json",
)

IARA.close_study!(db)
