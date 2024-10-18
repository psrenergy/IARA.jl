#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

"""
    PlotTechnologyHistogramStageBlock

Type for plotting a histogram where the observations are the total of generation for a technology at block i, stage j, considering all scenarios.
"""
abstract type PlotTechnologyHistogramStageBlock <: PlotType end

function plot_data(
    ::Type{PlotTechnologyHistogramStageBlock},
    data::Array{Float32, N},
    agent_names::Vector{String},
    dimensions::Vector{String};
    title::String = "",
    unit::String = "",
    file_path::String,
    kwargs...,
) where {N}

    # observations are each scenario for plant i in block - stage j
    num_stages = size(data, 4)
    num_scenarios = size(data, 3)
    num_blocks = size(data, 2)

    data_to_plot = Vector{Vector{Float64}}()
    for stage in 1:num_stages
        for block in 1:num_blocks
            data_for_stage_block = Vector{Float64}()
            for scenario in 1:num_scenarios
                push!(data_for_stage_block, sum(data[:, block, scenario, stage]))
            end
            push!(data_to_plot, data_for_stage_block)
        end
    end

    configs = Vector{Config}()
    for stage in 1:num_stages
        for block in 1:num_blocks
            push!(
                configs,
                Config(;
                    x = data_to_plot[block],
                    type = "histogram",
                    name = "Block $block - Stage $stage",
                ),
            )
        end
    end

    main_configuration = Config(;
        title = title * " - Stage - Block",
        xaxis = Dict("title" => unit),
        yaxis = Dict("title" => "Frequency"),
    )

    if file_path == ""
        return Plot(configs, main_configuration)
    else
        _save_plot(Plot(configs, main_configuration), file_path * "_hist_stage_block.html")
    end

    return
end
