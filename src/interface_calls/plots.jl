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

    # Plot inflows
    inflow_file = joinpath(IARA.path_case(inputs), IARA.hydro_unit_inflow_ex_ante_file(inputs))
    inflow_file *= timeseries_file_extension(inflow_file)
    if isfile(inflow_file)
        IARA.custom_plot(
            inflow_file,
            IARA.PlotTimeSeriesAll;
            title = "Inflows",
            plot_path = joinpath(IARA.output_path(inputs), "inflows"),
        )
    end

    # Plot demand
    demand_file = joinpath(IARA.path_case(inputs), IARA.demand_unit_demand_ex_ante_file(inputs))
    demand_file *= timeseries_file_extension(demand_file)
    if isfile(demand_file)
        IARA.custom_plot(
            demand_file,
            IARA.PlotTimeSeriesAll;
            title = "Demand",
            plot_path = joinpath(IARA.output_path(inputs), "demand"),
        )
    end

    # Plot renewable generation
    renewable_generation_file = joinpath(IARA.path_case(inputs), IARA.renewable_unit_generation_ex_ante_file(inputs))
    renewable_generation_file *= timeseries_file_extension(renewable_generation_file)
    if isfile(renewable_generation_file)
        IARA.custom_plot(
            renewable_generation_file,
            IARA.PlotTimeSeriesAll;
            title = "Renewable Generation",
            plot_path = joinpath(IARA.output_path(inputs), "renewable_generation"),
        )
    end
    return nothing
end
