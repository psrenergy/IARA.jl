#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

module TestCase01MarkupBidsCase

using Test
using IARA

const PATH = @__DIR__
# base_case_path = joinpath(PATH, "../base_case")
include("../base_case/build_base_case.jl")
IARA.main([PATH])
mv(joinpath(PATH, "outputs/hydro_generation.toml"), joinpath(PATH, "hydro_generation.toml"); force = true)
mv(joinpath(PATH, "outputs/hydro_generation.csv"), joinpath(PATH, "hydro_generation.csv"); force = true)
mv(
    joinpath(PATH, "outputs/hydro_opportunity_cost.toml"),
    joinpath(PATH, "hydro_opportunity_cost.toml");
    force = true,
)
mv(
    joinpath(PATH, "outputs/hydro_opportunity_cost.csv"),
    joinpath(PATH, "hydro_opportunity_cost.csv");
    force = true,
)
include("build_markup_bids_case.jl")

IARA.main([PATH])

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH)
end

end
