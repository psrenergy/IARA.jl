#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

# You should run the script from the profiling directory

using Profile
using PProf
import Pkg
root_path = dirname(@__DIR__)
Pkg.activate(root_path)
using IARA
using Test

include("../test/utils.jl")
include("../test/case_01/big_simulation_case/test_case.jl")
IARA.main([Main.TestCase01BigSimulationCase.PATH, "--run-mode=train-min-cost"])
IARA.main([Main.TestCase01BigSimulationCase.PATH, "--run-mode=train-min-cost"])
Profile.clear()
@profile IARA.main([Main.TestCase01BigSimulationCase.PATH, "--run-mode=train-min-cost"])
@profile Main.compare_outputs(Main.TestCase01BigSimulationCase.PATH)
pprof()
