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

PATH_BASE_CASE = joinpath(PATH, "..", "base_case")
path_base_case_cuts = joinpath(PATH_BASE_CASE, "outputs", "cuts.json")
path_cuts = joinpath(PATH, "cuts.json")

cp(path_base_case_cuts, path_cuts; force = true)

IARA.link_time_series_to_file(
    db,
    "Configuration";
    fcf_cuts = "cuts.json",
)

IARA.update_configuration!(
    db;
    market_clearing_tiebreaker_weight = 1e-4,
    use_fcf_in_clearing = 1,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
)

IARA.close_study!(db)