#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

abstract type PlotTechnologyHistogram <: PlotType end

function plot_data(
    ::Type{PlotTechnologyHistogram},
    data::Array{Float32, N},
    agent_names::Vector{String},
    dimensions::Vector{String};
    title::String = "",
    unit::String = "",
    file_path::String,
    initial_date::DateTime,
    stage_type::Configurations_StageType.T,
) where {N}

    # observations are each scenario - block for plant i
    num_stages = size(data, 4)
    num_scenarios = size(data, 3)
    num_blocks = size(data, 2)

    data_to_plot = Vector{Float64}()
    for scenario in 1:num_scenarios
        for block in 1:num_blocks
            for stage in 1:num_stages
                push!(data_to_plot, sum(data[:, block, scenario, stage]))
            end
        end
    end

    plot_ref = plot()
    plot_ref(;
        x = data_to_plot,
        type = "histogram",
    )

    plot_ref.layout.title.text = title * " - Scenario - Block"
    plot_ref.layout.xaxis.title = unit
    plot_ref.layout.yaxis.title = "Frequency"

    _save_plot(plot_ref, file_path * "_hist.html")

    return
end
