#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function create_plots(inputs::IARA.AbstractInputs)
    # Create plots
    @info("Creating plots")
    plots_path = joinpath(IARA.output_path(inputs), "plots")
    if !isdir(plots_path)
        mkdir(plots_path)
    end
    IARA.plot_demand(inputs, plots_path)

    return nothing
end
