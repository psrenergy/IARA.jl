#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

# Configuration file for JuliaFormatter.jl
# For more information, see: https://domluna.github.io/JuliaFormatter.jl/stable/config/

import Pkg
Pkg.instantiate()

using JuliaFormatter

format(dirname(@__DIR__))
format(dirname(@__DIR__))
println("Formatted: ", format(dirname(@__DIR__)))
