#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function fill_flexible_demand_window_caches!(inputs, demand_window::Array{Int, 2})
    num_demands = number_of_elements(inputs, Demand)

    number_of_flexible_demand_windows = zeros(Int, num_demands)
    blocks_in_flexible_demand_window = [Vector{Int}[] for d in 1:num_demands]

    for flexible_demand in index_of_elements(inputs, Demand; filters = [is_flexible])
        number_of_windows = maximum(demand_window[flexible_demand, :])
        number_of_flexible_demand_windows[flexible_demand] = number_of_windows

        blocks_in_flexible_demand_window[flexible_demand] =
            [Int[] for w in 1:number_of_windows]

        for window in 1:number_of_windows
            blocks = findall(x -> x == window, demand_window[flexible_demand, :])
            blocks_in_flexible_demand_window[flexible_demand][window] = blocks
        end
    end

    inputs.collections.demand._number_of_flexible_demand_windows =
        number_of_flexible_demand_windows
    inputs.collections.demand._blocks_in_flexible_demand_window =
        blocks_in_flexible_demand_window

    return nothing
end
