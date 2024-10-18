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

include("../test/case_01/gnd_modifications_case/test_gnd_modifications_case.jl")
IARA.main([Main.TestCase01GNDModificationsCase.PATH])
IARA.main([Main.TestCase01GNDModificationsCase.PATH])
@profile IARA.main([Main.TestCase01GNDModificationsCase.PATH])
pprof()
