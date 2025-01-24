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

module TestCase10SinglePeriodHeuristicBid

using Test
using IARA

const PATH = @__DIR__

db = nothing
try
    include("../guess_bid/build_case.jl")
finally
    if db !== nothing
        IARA.close_study!(db)
    end
end

output_path = joinpath(PATH, "outputs")
IARA.single_period_heuristic_bid(
    PATH;
    period = 1,
    output_path = joinpath(output_path, "period_1"),
    plot_outputs = false,
    delete_output_folder_before_execution = true,
)
IARA.single_period_heuristic_bid(
    PATH;
    period = 2,
    output_path = joinpath(output_path, "period_2"),
    plot_outputs = false,
    delete_output_folder_before_execution = true,
)
IARA.single_period_heuristic_bid(
    PATH;
    period = 3,
    output_path = joinpath(output_path, "period_3"),
    plot_outputs = false,
    delete_output_folder_before_execution = true,
)

Main.send_files(joinpath(output_path, "period_1"), output_path)
Main.send_files(joinpath(output_path, "period_2"), output_path)
Main.send_files(joinpath(output_path, "period_3"), output_path)

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH)
end

end
