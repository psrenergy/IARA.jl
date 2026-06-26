#############################################################################
#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

module TestCase01ThermalRampValidationCase

using Test
using IARA
using DataFrames
using Dates

const PATH = @__DIR__

# IARA.validate creates an output directory and refuses to run when it already
# exists, so we clear it before every validation call.
function clean_outputs()
    output_dir = joinpath(PATH, "outputs")
    if isdir(output_dir)
        rm(output_dir; recursive = true, force = true)
    end
    return nothing
end

db = nothing
try
    include("../base_case/build_case.jl")
finally
    if db !== nothing
        IARA.close_study!(db)
    end
end

# A zero max_ramp_up must be a validation error.
db = IARA.load_study(PATH; read_only = false)
IARA.update_thermal_unit!(db, "ter_1"; max_ramp_up = 0.0)
IARA.close_study!(db)
clean_outputs()
@test_throws "validation errors" IARA.validate(PATH; run_mode = "train-min-cost")

# A zero max_ramp_down must be a validation error (with a positive up limit).
db = IARA.load_study(PATH; read_only = false)
IARA.update_thermal_unit!(db, "ter_1"; max_ramp_up = 0.2 / 60, max_ramp_down = 0.0)
IARA.close_study!(db)
clean_outputs()
@test_throws "validation errors" IARA.validate(PATH; run_mode = "train-min-cost")

# Control: positive limits on both sides validate cleanly.
db = IARA.load_study(PATH; read_only = false)
IARA.update_thermal_unit!(db, "ter_1"; max_ramp_up = 0.2 / 60, max_ramp_down = 0.2 / 60)
IARA.close_study!(db)
clean_outputs()
@test IARA.validate(PATH; run_mode = "train-min-cost")

clean_outputs()

end
