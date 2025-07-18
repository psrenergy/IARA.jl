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

module TestICSP_2_12_15_Case

using Test
using IARA

const PATH = @__DIR__

if Main.RUN_BIG_TESTS
    db = nothing
    try
        include("../case_2_180_1/build_case.jl")
        include("./modify_case.jl")
    finally
        if db !== nothing
            IARA.close_study!(db)
        end
    end

    IARA.train_min_cost(PATH; plot_outputs = false, delete_output_folder_before_execution = true)

    if Main.UPDATE_RESULTS
        Main.update_outputs!(PATH)
    else
        Main.compare_outputs(PATH)
    end
end

end
