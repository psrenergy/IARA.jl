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
    PlotType

Abstract type for a plot type.
"""
abstract type PlotType end

"""
    plot_data

Concrete implementation on how to plot a specific plot type.
"""
function plot_data end

function merge_scenario_agent end
_save_plot(plot_reference, file) = PlotlyLight.save(plot_reference, file)

"""
    PlotConfig

Configuration for a plot.
"""
mutable struct PlotConfig
    title::String
    filename::String
    plot_types::Array{DataType, 1}
    initial_date_time::DateTime
    stage_type::Configurations_StageType.T
end

function PlotConfig(
    title::String,
    filename::String,
    plot_types::Array{DataType, 1},
    inputs::Inputs,
)
    return PlotConfig(title, filename, plot_types, initial_date_time(inputs), stage_type(inputs))
end

function _snake_to_regular(snake_str::String)
    words = split(snake_str, '_')
    capitalized_words = map(uppercasefirst, words)
    return join(capitalized_words, " ")
end

function set_plot_defaults()
    PlotlyLight.template!("plotly_white")
    return nothing
end

function get_plot_color(index::Int; transparent::Bool = false)
    colors = [
        "rgb(31, 119, 180)",
        "rgb(255, 127, 14)",
        "rgb(44, 160, 44)",
        "rgb(214, 39, 40)",
        "rgb(148, 103, 189)",
        "rgb(140, 86, 75)",
        "rgb(227, 119, 194)",
        "rgb(127, 127, 127)",
        "rgb(188, 189, 34)",
        "rgb(23, 190, 207)",
    ]

    color = colors[mod1(index, length(colors))]

    if transparent
        color = replace(color, "rgb" => "rgba")
        color = replace(color, ")" => ", 0.2)")
    end

    return color
end

function get_plot_ticks(
    data::Array{Float64, 2},
    num_stages::Int,
    initial_date_time::DateTime,
    stage_type::Configurations_StageType.T,
)
    num_ticks = size(data, 2)
    num_blocks = 0
    if num_stages != num_ticks
        num_blocks = num_ticks ÷ num_stages
    end
    plot_ticks = Vector{String}()
    hover_ticks = Vector{String}()

    if stage_type == Configurations_StageType.MONTHLY
        if num_blocks == 0
            for i in 0:num_stages-1
                push!(plot_ticks, Dates.format(initial_date_time + Dates.Month(i), "yyyy/mm"))
                push!(hover_ticks, Dates.format(initial_date_time + Dates.Month(i), "yyyy/mm"))
            end
            return plot_ticks, hover_ticks
        else
            for i in 0:num_stages-1
                for j in 1:num_blocks
                    if j == 1
                        push!(plot_ticks, Dates.format(initial_date_time + Dates.Month(i), "yyyy/mm"))
                    else
                        push!(plot_ticks, "") # we do not display ticks for each block, only when hovering
                    end
                    push!(hover_ticks, Dates.format(initial_date_time + Dates.Month(i), "yyyy/mm") * "<br>Block $j")
                end
            end
            return plot_ticks, hover_ticks
        end
    else
        error("Stage type not implemented.")
    end
end

function merge_stage_block(data::Array{T, 4}) where {T <: Real}
    num_stages = size(data, 4)
    num_scenarios = size(data, 3)
    num_blocks = size(data, 2)
    num_agents = size(data, 1)

    reshaped_data =
        Array{Float64, 3}(undef, num_agents, num_scenarios, num_stages * num_blocks)
    i = 1
    for stage in 1:num_stages
        for block in 1:num_blocks
            reshaped_data[:, :, i] = data[:, block, :, stage]
            i += 1
        end
    end

    return reshaped_data
end

function merge_stage_block(data::Array{T, 5}) where {T <: Real}
    num_stages = size(data, 5)
    num_scenarios = size(data, 4)
    num_subscenarios = size(data, 3)
    num_blocks = size(data, 2)
    num_agents = size(data, 1)

    reshaped_data =
        Array{Float64, 4}(undef, num_agents, num_subscenarios, num_scenarios, num_stages * num_blocks)
    i = 1
    for stage in 1:num_stages
        for block in 1:num_blocks
            reshaped_data[:, :, :, i] = data[:, block, :, :, stage]
            i += 1
        end
    end

    return reshaped_data
end

function merge_segment_agent(data::Array{Float32, 4}, agent_names::Vector{String})
    num_segments = size(data, 2)
    num_agents = size(data, 1)
    num_scenarios = size(data, 3)
    num_stages = size(data, 4)

    reshaped_data = Array{Float64, 3}(undef, num_agents * num_segments, num_scenarios, num_stages)
    modified_names = Vector{String}(undef, num_agents * num_segments)

    for stage in 1:num_stages
        for scenario in 1:num_scenarios
            for segment in 1:num_segments
                for agent in 1:num_agents
                    reshaped_data[(agent-1)*num_segments+segment, scenario, stage] =
                        data[agent, segment, scenario, stage]
                    modified_names[(agent-1)*num_segments+segment] = agent_names[agent] * " (Segment $segment)"
                end
            end
        end
    end
    return reshaped_data, modified_names
end

function merge_segment_agent(data::Array{Float32, 5}, agent_names::Vector{String})
    num_segments = size(data, 2)
    num_agents = size(data, 1)
    num_scenarios = size(data, 4)
    num_stages = size(data, 5)
    num_blocks = size(data, 3)

    reshaped_data = Array{Float64, 4}(undef, num_agents * num_segments, num_blocks, num_scenarios, num_stages)
    modified_names = Vector{String}(undef, num_agents * num_segments)

    for stage in 1:num_stages
        for scenario in 1:num_scenarios
            for block in 1:num_blocks
                for segment in 1:num_segments
                    for agent in 1:num_agents
                        reshaped_data[(agent-1)*num_segments+segment, block, scenario, stage] =
                            data[agent, segment, block, scenario, stage]
                        modified_names[(agent-1)*num_segments+segment] = agent_names[agent] * " (Segment $segment)"
                    end
                end
            end
        end
    end
    return reshaped_data, modified_names
end

function merge_segment_agent(data::Array{Float32, 6}, agent_names::Vector{String})
    num_agents = size(data, 1)
    num_segments = size(data, 2)
    num_scenarios = size(data, 5)
    num_stages = size(data, 6)
    num_subscenarios = size(data, 4)
    num_blocks = size(data, 3)

    reshaped_data =
        Array{Float64, 5}(undef, num_agents * num_segments, num_blocks, num_scenarios, num_subscenarios, num_stages)
    modified_names = Vector{String}(undef, num_agents * num_segments)

    for stage in 1:num_stages
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for block in 1:num_blocks
                    for segment in 1:num_segments
                        for agent in 1:num_agents
                            reshaped_data[(agent-1)*num_segments+segment, block, scenario, subscenario, stage] =
                                data[agent, segment, block, subscenario, scenario, stage]
                            modified_names[(agent-1)*num_segments+segment] = agent_names[agent] * " (Segment $segment)"
                        end
                    end
                end
            end
        end
    end
    return reshaped_data, modified_names
end

function merge_scenario_subscenario_agent(data::Array{Float32, 4}, agent_names::Vector{String})
    num_subscenarios = size(data, 2)
    num_agents = size(data, 1)
    num_scenarios = size(data, 3)
    num_stageblock = size(data, 4)

    reshaped_data = Array{Float64, 2}(undef, num_agents * num_scenarios * num_subscenarios, num_stageblock)
    modified_names = Vector{String}(undef, num_agents * num_scenarios * num_subscenarios)

    for stageblock in 1:num_stageblock
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for agent in 1:num_agents
                    reshaped_data[
                        (agent-1)*num_subscenarios*num_scenarios+(subscenario-1)*num_scenarios+scenario,
                        stageblock,
                    ] =
                        data[agent, subscenario, scenario, stageblock]
                end
                modified_names[(agent-1)*num_subscenarios*num_scenarios+(subscenario-1)*num_scenarios+scenario] =
                    agent_names[agent] * " (Scenario $scenario - Subscenario $subscenario)"
            end
        end
    end
    return reshaped_data, modified_names
end

function merge_scenario_subscenario(
    data::Array{T, 4},
    agent_names::Vector{String},
) where {T <: Real}
    num_subscenarios = size(data, 2)
    num_agents = size(data, 1)
    num_scenarios = size(data, 3)
    num_stageblock = size(data, 4)

    reshaped_data = Array{Float64, 3}(undef, num_agents, num_scenarios * num_subscenarios, num_stageblock)
    modified_scenario_names = Vector{String}(undef, num_scenarios * num_subscenarios)

    for scenario in 1:num_scenarios
        for subscenario in 1:num_subscenarios
            for agent in 1:num_agents
                reshaped_data[agent, (scenario-1)*num_subscenarios+subscenario, :] =
                    data[agent, subscenario, scenario, :]
            end
            modified_scenario_names[(scenario-1)*num_subscenarios+subscenario] = "( Scenario $scenario - Subscenario $subscenario )"
        end
    end

    return reshaped_data, modified_scenario_names
end

function build_plot_output(
    inputs::Inputs,
    plots_path::String,
    outputs_path::String,
    plot_config::PlotConfig,
)
    file_path_without_extension = joinpath(outputs_path, plot_config.filename)
    if !quiver_file_exists(file_path_without_extension)
        @debug("Tried to build plot output for $(plot_config.filename) but no Quiver file found.")
        return nothing
    end
    file_path = get_quiver_file_path(file_path_without_extension)
    output_data, metadata = read_timeseries_file(file_path)
    output_labels = metadata.labels
    unit = metadata.unit
    output_dimensions = String.(metadata.dimensions)

    for plot_type in plot_config.plot_types
        plot_data(
            plot_type,
            output_data,
            output_labels,
            output_dimensions;
            title = plot_config.title,
            unit = unit,
            file_path = joinpath(plots_path, plot_config.filename),
            initial_date = plot_config.initial_date_time,
            stage_type = plot_config.stage_type,
        )
    end

    return nothing
end

"""
    build_plots(inputs::Inputs)

Build plots for the outputs of the model.
"""
function build_plots(
    inputs::Inputs,
)
    println("Building plots")
    plots_path = joinpath(output_path(inputs), "plots")
    if !isdir(plots_path)
        mkdir(plots_path)
    end

    plot_configs = PlotConfig[]

    if number_of_elements(inputs, HydroPlant) > 0
        # Hydro Volume
        plot_config_hydro_volume = PlotConfig(
            "Hydro Initial Volume",
            "hydro_initial_volume",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramStage,
                PlotTechnologyHistogramBlock,
                PlotTechnologyHistogramStageBlock,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_hydro_volume)

        # Hydro Turbining
        plot_config_hydro_turbining = PlotConfig(
            "Hydro Turbining",
            "hydro_turbining",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramStage,
                PlotTechnologyHistogramBlock,
                PlotTechnologyHistogramStageBlock,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_hydro_turbining)

        # Hydro Inflow
        plot_config_hydro_inflow = PlotConfig(
            "Hydro Inflow",
            "inflow",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramStage,
                PlotTechnologyHistogramBlock,
                PlotTechnologyHistogramStageBlock,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_hydro_inflow)

        # Hydro Generation
        plot_config_hydro_generation = PlotConfig(
            "Hydro Generation",
            "hydro_generation",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramStage,
                PlotTechnologyHistogramBlock,
                PlotTechnologyHistogramStageBlock,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_hydro_generation)

        # Hydro Spillage
        plot_config_hydro_spillage = PlotConfig(
            "Hydro Spillage",
            "hydro_spillage",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramStage,
                PlotTechnologyHistogramBlock,
                PlotTechnologyHistogramStageBlock,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_hydro_spillage)
    end

    if number_of_elements(inputs, ThermalPlant) > 0
        # Thermal Generation
        plot_config_thermal_generation = PlotConfig(
            "Thermal Generation",
            "thermal_generation",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramStage,
                PlotTechnologyHistogramBlock,
                PlotTechnologyHistogramStageBlock,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_thermal_generation)
    end

    if number_of_elements(inputs, RenewablePlant) > 0
        # Renewable Generation
        plot_config_renewable_generation = PlotConfig(
            "Renewable Generation",
            "renewable_generation",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramStage,
                PlotTechnologyHistogramBlock,
                PlotTechnologyHistogramStageBlock,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_renewable_generation)

        # Renewable Curtailment
        plot_config_renewable_curtailment = PlotConfig(
            "Renewable Curtailment",
            "renewable_curtailment",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramStage,
                PlotTechnologyHistogramBlock,
                PlotTechnologyHistogramStageBlock,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_renewable_curtailment)
    end

    if number_of_elements(inputs, DCLine) > 0 &&
       run_mode(inputs) != Configurations_RunMode.STRATEGIC_BID &&
       run_mode(inputs) != Configurations_RunMode.PRICE_TAKER_BID
        # DC Line Flow
        plot_config_dc_flow = PlotConfig(
            "DC Line Flow",
            "dc_flow",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_dc_flow)
    end

    if run_mode(inputs) == Configurations_RunMode.CENTRALIZED_OPERATION
        # Deficit
        plot_config_deficit = PlotConfig(
            "Deficit",
            "deficit",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_deficit)

        # Demand
        plot_config_demand = PlotConfig(
            "Demand",
            "demand",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_demand)

        # Generation
        plot_config_generation = PlotConfig(
            "Generation",
            "generation",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_generation)
    end

    if !use_binary_variables(inputs) &&
       run_mode(inputs) != Configurations_RunMode.STRATEGIC_BID
        # Load Marginal Cost
        plot_config_load_marginal_cost = PlotConfig(
            "Load Marginal Cost",
            "load_marginal_cost",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_load_marginal_cost)
    end

    if run_mode(inputs) == Configurations_RunMode.HEURISTIC_BID
        # Energy offer
        plot_config_energy = PlotConfig(
            "Energy Offer per Bidding Group",
            "bidding_group_energy_offer",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_energy)

        # Price offer
        plot_config_price = PlotConfig(
            "Price Offer per Bidding Group",
            "bidding_group_price_offer",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_price)
    end

    if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING
        for file in readdir(output_path(inputs))
            if occursin(".csv", file)
                final_file_name = _snake_to_regular(String(split(file, ".")[1]))
                if occursin("Post", final_file_name)
                    final_file_name = replace(final_file_name, "Ex Post" => "Ex-Post")
                elseif occursin("Ante", final_file_name)
                    final_file_name = replace(final_file_name, "Ex Ante" => "Ex-Ante")
                end
                plot_config_clearing = PlotConfig(
                    final_file_name,
                    split(file, ".")[1],
                    [PlotTimeSeriesQuantiles, PlotTimeSeriesMean, PlotTimeSeriesAll],
                    initial_date_time(inputs),
                    stage_type(inputs),
                )
                push!(plot_configs, plot_config_clearing)
            end
        end
    end

    for plot_config in plot_configs
        build_plot_output(inputs, plots_path, output_path(inputs), plot_config)
    end

    return nothing
end
