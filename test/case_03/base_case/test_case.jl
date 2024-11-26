#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

module TestCase03BaseCase

using Test
using IARA

const PATH = @__DIR__

include("build_case.jl")

IARA.train_min_cost(PATH; plot_outputs = false)

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    # Because of the flexibility, the demand can be attended in any subperiod of each window, and it causes 
    # the attended_demand and thermal_generation to be degenerate within a window. Also, the total deficit 
    # and curtailment of a window can be distributed among its subperiods in different ways, causing also the 
    # deficit and demand_curtailment to be degenerate within a window. Therefore, we test only the sum of 
    # these outputs within each period and scenario, aggregating the subperiods.
    Main.compare_outputs(
        PATH;
        test_only_subperiod_sum = [
            "deficit",
            "demand_curtailment",
            "attended_demand",
            "attended_flexible_demand",
            "thermal_generation",
        ],
    )
end

end
