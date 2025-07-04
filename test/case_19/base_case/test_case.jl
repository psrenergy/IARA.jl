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

module TestCase19BaseCase

using Test
using IARA

const PATH = @__DIR__

db = nothing
try
    include("build_case.jl")
finally
    if db !== nothing
        IARA.close_study!(db)
    end
end

IARA.market_clearing(PATH; plot_outputs = false, delete_output_folder_before_execution = true)

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH;
        test_only_subperiod_sum = [
            "bidding_group_generation",
            "hydro_generation",
            "hydro_om_costs",
            "hydro_turbining",
            "thermal_generation",
            "thermal_om_costs",
        ],
        skipped_outputs = [
            "hydro_final_volume",
            "hydro_initial_volume",
        ],
    )
end

end
