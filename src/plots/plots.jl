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
    RelationPlotType

Abstract type for a plot type.
"""
abstract type RelationPlotType <: PlotType end

"""
    plot_data(::Type{<:PlotType}, data::Array{<:AbstractFloat, N}, agent_names::Vector{String}, dimensions::Vector{String}; kwargs...)

Plot the data for a specific plot type.
"""
function plot_data end

"""
    merge_scenario_agent(::Type{<:PlotType}, data::Array{<:AbstractFloat, N}, agent_names::Vector{String}, scenario_names::Union{Vector{String}, Nothing}; kwargs...) where {N}

Reduce the dimension of the data array by merging the scenario and agent dimensions.
"""
function merge_scenario_agent end

"""
    merge_period_subperiod(data::Array{T, N}) where {T <: AbstractFloat, N}

Reduce the dimension of the data array by merging the period and subperiod dimensions.
"""
function merge_period_subperiod end

"""
    merge_segment_agent(data::Array{<:AbstractFloat, N}, agent_names::Vector{String}; kwargs...) where {N}

Reduce the dimension of the data array by merging the segment and agent dimensions.
"""
function merge_segment_agent end

"""
    merge_scenario_subscenario_agent(data::Array{<:AbstractFloat, N}, agent_names::Vector{String}; kwargs...) where {N}

Reduce the dimension of the data array by merging the scenario, subscenario, and agent dimensions.
"""
function merge_scenario_subscenario_agent end

"""
    merge_scenario_subscenario(data::Array{<:AbstractFloat, N}, agent_names::Vector{String}; kwargs...) where {N}

Reduce the dimension of the data array by merging the scenario and subscenario dimensions.
"""
function merge_scenario_subscenario end

"""
    reshape_time_series!(::Type{<:PlotType}, data::Array{<:AbstractFloat, N}, agent_names::Vector{String}, dimensions::Vector{String}; kwargs...)

Reduce the dimension of the data array by merging the dimensions, according to the plot type.
"""
function reshape_time_series! end

"""
    PlotConfig

Configuration for a plot.
"""
mutable struct PlotConfig
    title::String
    filename::String
    plot_types::Array{DataType, 1}
    initial_date_time::DateTime
    time_series_step::Configurations_TimeSeriesStep.T
end

function PlotConfig(
    title::String,
    filename::String,
    plot_types::Array{DataType, 1},
    inputs::Inputs,
)
    return PlotConfig(title, filename, plot_types, initial_date_time(inputs), time_series_step(inputs))
end

_save_plot(plot_reference, file) = PlotlyLight.save(plot_reference, file)

function _snake_to_regular(snake_str::String)
    words = split(snake_str, '_')
    capitalized_words = map(uppercasefirst, words)
    return join(capitalized_words, " ")
end

function initialize_plotly()
    PlotlyLight.plotly = PlotlyLight.PlotlyArtifacts()
    PlotlyLight.template!("plotly_white")
    return nothing
end

function _get_plot_color(index::Int; transparent::Bool = false)
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

function _get_plot_ticks(
    data::Array{<:AbstractFloat, 2},
    num_periods::Int,
    initial_date_time::DateTime,
    time_series_step::Configurations_TimeSeriesStep.T;
    kwargs...,
)
    queried_subperiods = get(kwargs, :subperiod, nothing)

    num_ticks = size(data, 2)
    num_subperiods = 0
    if num_periods != num_ticks
        num_subperiods = num_ticks ÷ num_periods
    end
    plot_ticks = Vector{String}()
    hover_ticks = Vector{String}()

    if time_series_step == Configurations_TimeSeriesStep.ONE_MONTH_PER_PERIOD
        if num_subperiods == 0
            for i in 0:num_periods-1
                push!(plot_ticks, Dates.format(initial_date_time + Dates.Month(i), "yyyy/mm"))
                subperiod_true_index = isnothing(queried_subperiods) ? 1 : queried_subperiods[1]
                push!(
                    hover_ticks,
                    Dates.format(initial_date_time + Dates.Month(i), "yyyy/mm") * "<br>Subperiod $subperiod_true_index",
                )
            end
            return plot_ticks, hover_ticks
        else
            for i in 0:num_periods-1
                for j in 1:num_subperiods
                    if j == 1
                        push!(plot_ticks, Dates.format(initial_date_time + Dates.Month(i), "yyyy/mm"))
                    else
                        push!(plot_ticks, "") # we do not display ticks for each subperiod, only when hovering
                    end
                    subperiod_true_index = isnothing(queried_subperiods) ? j : queried_subperiods[j]
                    push!(
                        hover_ticks,
                        Dates.format(initial_date_time + Dates.Month(i), "yyyy/mm") *
                        "<br>Subperiod $subperiod_true_index",
                    )
                end
            end
            return plot_ticks, hover_ticks
        end
    else
        error("Time series step not implemented.")
    end
end

function merge_period_subperiod(data::Array{<:AbstractFloat, 4})
    num_periods = size(data, 4)
    num_scenarios = size(data, 3)
    num_subperiods = size(data, 2)
    num_agents = size(data, 1)

    reshaped_data =
        Array{AbstractFloat, 3}(undef, num_agents, num_scenarios, num_periods * num_subperiods)
    i = 1
    for period in 1:num_periods
        for subperiod in 1:num_subperiods
            reshaped_data[:, :, i] = data[:, subperiod, :, period]
            i += 1
        end
    end

    return reshaped_data
end

function merge_period_subperiod(data::Array{<:AbstractFloat, 5})
    num_periods = size(data, 5)
    num_scenarios = size(data, 4)
    num_subscenarios = size(data, 3)
    num_subperiods = size(data, 2)
    num_agents = size(data, 1)

    reshaped_data =
        Array{AbstractFloat, 4}(undef, num_agents, num_subscenarios, num_scenarios, num_periods * num_subperiods)
    i = 1
    for period in 1:num_periods
        for subperiod in 1:num_subperiods
            reshaped_data[:, :, :, i] = data[:, subperiod, :, :, period]
            i += 1
        end
    end

    return reshaped_data
end

function merge_segment_agent(data::Array{<:AbstractFloat, 4}, agent_names::Vector{String}; kwargs...)
    num_segments = size(data, 2)
    num_agents = size(data, 1)
    num_scenarios = size(data, 3)
    num_periods = size(data, 4)

    queried_segments = get(kwargs, :segment, nothing)

    reshaped_data = Array{AbstractFloat, 3}(undef, num_agents * num_segments, num_scenarios, num_periods)
    modified_names = Vector{String}(undef, num_agents * num_segments)

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for segment in 1:num_segments
                for agent in 1:num_agents
                    reshaped_data[(agent-1)*num_segments+segment, scenario, period] =
                        data[agent, segment, scenario, period]
                    segment_true_index = isnothing(queried_segments) ? segment : queried_segments[segment]

                    modified_names[(agent-1)*num_segments+segment] =
                        agent_names[agent] * " (Segment $segment_true_index)"
                end
            end
        end
    end
    return reshaped_data, modified_names
end

function merge_segment_agent(data::Array{<:AbstractFloat, 5}, agent_names::Vector{String}; kwargs...)
    num_segments = size(data, 2)
    num_agents = size(data, 1)
    num_scenarios = size(data, 4)
    num_periods = size(data, 5)
    num_subperiods = size(data, 3)

    queried_segments = get(kwargs, :segment, nothing)

    reshaped_data =
        Array{AbstractFloat, 4}(undef, num_agents * num_segments, num_subperiods, num_scenarios, num_periods)
    modified_names = Vector{String}(undef, num_agents * num_segments)

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subperiod in 1:num_subperiods
                for segment in 1:num_segments
                    for agent in 1:num_agents
                        reshaped_data[(agent-1)*num_segments+segment, subperiod, scenario, period] =
                            data[agent, segment, subperiod, scenario, period]
                        segment_true_index = isnothing(queried_segments) ? segment : queried_segments[segment]

                        modified_names[(agent-1)*num_segments+segment] =
                            agent_names[agent] * " (Segment $segment_true_index)"
                    end
                end
            end
        end
    end
    return reshaped_data, modified_names
end

function merge_segment_agent(data::Array{<:AbstractFloat, 6}, agent_names::Vector{String}; kwargs...)
    num_agents = size(data, 1)
    num_segments = size(data, 2)
    num_scenarios = size(data, 5)
    num_periods = size(data, 6)
    num_subscenarios = size(data, 4)
    num_subperiods = size(data, 3)

    queried_segments = get(kwargs, :segment, nothing)

    reshaped_data =
        Array{AbstractFloat, 5}(
            undef,
            num_agents * num_segments,
            num_subperiods,
            num_scenarios,
            num_subscenarios,
            num_periods,
        )
    modified_names = Vector{String}(undef, num_agents * num_segments)

    for period in 1:num_periods
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for subperiod in 1:num_subperiods
                    for segment in 1:num_segments
                        for agent in 1:num_agents
                            reshaped_data[(agent-1)*num_segments+segment, subperiod, scenario, subscenario, period] =
                                data[agent, segment, subperiod, subscenario, scenario, period]
                            segment_true_index = isnothing(queried_segments) ? segment : queried_segments[segment]
                            modified_names[(agent-1)*num_segments+segment] =
                                agent_names[agent] * " (Segment $segment_true_index)"
                        end
                    end
                end
            end
        end
    end
    return reshaped_data, modified_names
end

function merge_scenario_subscenario_agent(data::Array{<:AbstractFloat, 4}, agent_names::Vector{String}; kwargs...)
    num_subscenarios = size(data, 2)
    num_agents = size(data, 1)
    num_scenarios = size(data, 3)
    num_periodsubperiod = size(data, 4)

    queried_scenarios = get(kwargs, :scenario, nothing)
    queried_subscenarios = get(kwargs, :subscenario, nothing)

    reshaped_data = Array{AbstractFloat, 2}(undef, num_agents * num_scenarios * num_subscenarios, num_periodsubperiod)
    modified_names = Vector{String}(undef, num_agents * num_scenarios * num_subscenarios)

    for periodsubperiod in 1:num_periodsubperiod
        for scenario in 1:num_scenarios
            for subscenario in 1:num_subscenarios
                for agent in 1:num_agents
                    reshaped_data[
                        (agent-1)*num_subscenarios*num_scenarios+(subscenario-1)*num_scenarios+scenario,
                        periodsubperiod,
                    ] =
                        data[agent, subscenario, scenario, periodsubperiod]
                end
                scenario_true_index = isnothing(queried_scenarios) ? scenario : queried_scenarios[scenario]
                subscenario_true_index =
                    isnothing(queried_subscenarios) ? subscenario : queried_subscenarios[subscenario]
                modified_names[(agent-1)*num_subscenarios*num_scenarios+(subscenario-1)*num_scenarios+scenario] =
                    agent_names[agent] * " (Scenario $scenario_true_index - Subscenario $subscenario_true_index)"
            end
        end
    end
    return reshaped_data, modified_names
end

function merge_scenario_subscenario(
    data::Array{T, 4},
    agent_names::Vector{String};
    kwargs...,
) where {T <: AbstractFloat}
    num_subscenarios = size(data, 2)
    num_agents = size(data, 1)
    num_scenarios = size(data, 3)
    num_periodsubperiod = size(data, 4)

    queried_scenarios = get(kwargs, :scenario, nothing)
    queried_subscenarios = get(kwargs, :subscenario, nothing)

    reshaped_data = Array{AbstractFloat, 3}(undef, num_agents, num_scenarios * num_subscenarios, num_periodsubperiod)
    modified_scenario_names = Vector{String}(undef, num_scenarios * num_subscenarios)

    for scenario in 1:num_scenarios
        for subscenario in 1:num_subscenarios
            for agent in 1:num_agents
                reshaped_data[agent, (scenario-1)*num_subscenarios+subscenario, :] =
                    data[agent, subscenario, scenario, :]
            end
            scenario_true_index = isnothing(queried_scenarios) ? scenario : queried_scenarios[scenario]
            subscenario_true_index = isnothing(queried_subscenarios) ? subscenario : queried_subscenarios[subscenario]
            modified_scenario_names[(scenario-1)*num_subscenarios+subscenario] = "( Scenario $scenario_true_index - Subscenario $subscenario_true_index )"
        end
    end

    return reshaped_data, modified_scenario_names
end

"""
    build_plot_output(inputs::Inputs, plots_path::String, outputs_path::String, plot_config::PlotConfig)

Build the plot output for a specific plot configuration.
"""
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
            time_series_step = plot_config.time_series_step,
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
    Log.info("Building plots")
    plots_path = joinpath(output_path(inputs), "plots")
    if !isdir(plots_path)
        mkdir(plots_path)
    end

    plot_configs = PlotConfig[]

    if number_of_elements(inputs, HydroUnit) > 0
        # Hydro Volume
        plot_config_hydro_volume = PlotConfig(
            "Hydro Initial Volume",
            "hydro_initial_volume",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramPeriod,
                PlotTechnologyHistogramSubperiod,
                PlotTechnologyHistogramPeriodSubperiod,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_hydro_volume)

        plot_config_hydro_volume = PlotConfig(
            "Hydro Final Volume",
            "hydro_final_volume",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramPeriod,
                PlotTechnologyHistogramSubperiod,
                PlotTechnologyHistogramPeriodSubperiod,
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
                PlotTechnologyHistogramPeriod,
                PlotTechnologyHistogramSubperiod,
                PlotTechnologyHistogramPeriodSubperiod,
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
                PlotTechnologyHistogramPeriod,
                PlotTechnologyHistogramSubperiod,
                PlotTechnologyHistogramPeriodSubperiod,
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
                PlotTechnologyHistogramPeriod,
                PlotTechnologyHistogramSubperiod,
                PlotTechnologyHistogramPeriodSubperiod,
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
                PlotTechnologyHistogramPeriod,
                PlotTechnologyHistogramSubperiod,
                PlotTechnologyHistogramPeriodSubperiod,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_hydro_spillage)
    end

    if number_of_elements(inputs, ThermalUnit) > 0
        # Thermal Generation
        plot_config_thermal_generation = PlotConfig(
            "Thermal Generation",
            "thermal_generation",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramPeriod,
                PlotTechnologyHistogramSubperiod,
                PlotTechnologyHistogramPeriodSubperiod,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_thermal_generation)
    end

    if number_of_elements(inputs, RenewableUnit) > 0
        # Renewable Generation
        plot_config_renewable_generation = PlotConfig(
            "Renewable Generation",
            "renewable_generation",
            [
                PlotTimeSeriesMean,
                PlotTimeSeriesAll,
                PlotTimeSeriesQuantiles,
                PlotTechnologyHistogram,
                PlotTechnologyHistogramPeriod,
                PlotTechnologyHistogramSubperiod,
                PlotTechnologyHistogramPeriodSubperiod,
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
                PlotTechnologyHistogramPeriod,
                PlotTechnologyHistogramSubperiod,
                PlotTechnologyHistogramPeriodSubperiod,
            ],
            inputs,
        )
        push!(plot_configs, plot_config_renewable_curtailment)
    end

    if number_of_elements(inputs, DCLine) > 0 &&
       run_mode(inputs) != RunMode.STRATEGIC_BID &&
       run_mode(inputs) != RunMode.PRICE_TAKER_BID
        # DC Line Flow
        plot_config_dc_flow = PlotConfig(
            "DC Line Flow",
            "dc_flow",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_dc_flow)
    end

    if run_mode(inputs) == RunMode.TRAIN_MIN_COST ||
       run_mode(inputs) == RunMode.MIN_COST
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
            "DemandUnit",
            "demand",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_demand)

        # Generation
        plot_config_generation = PlotConfig(
            "Generation",
            "generation",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles, PlotTimeSeriesStackedMean],
            inputs,
        )
        push!(plot_configs, plot_config_generation)
    end

    if !use_binary_variables(inputs) &&
       run_mode(inputs) != RunMode.STRATEGIC_BID
        # Load Marginal Cost
        plot_config_load_marginal_cost = PlotConfig(
            "Load Marginal Cost",
            "load_marginal_cost",
            [PlotTimeSeriesMean, PlotTimeSeriesAll, PlotTimeSeriesQuantiles],
            inputs,
        )
        push!(plot_configs, plot_config_load_marginal_cost)
    end

    if is_market_clearing(inputs)
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

    if is_market_clearing(inputs)
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
                    time_series_step(inputs),
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

function build_ui_individual_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots")

    # Bidding group file labels
    labels_per_asset_owner = Vector{Vector{String}}(undef, number_of_elements(inputs, AssetOwner))
    for asset_owner_index in index_of_elements(inputs, AssetOwner)
        bidding_group_labels = bidding_group_label(inputs)[bidding_group_asset_owner_index(inputs) .== asset_owner_index]
        labels_to_read = String[]
        for bg in bidding_group_labels
            for bus in bus_label(inputs)
                push!(labels_to_read, "$bg - $bus")
            end
        end
        labels_per_asset_owner[asset_owner_index] = labels_to_read
    end

    # Revenue
    # TODO: choose file correctly (after post-processing PR)
    revenue_file_path = joinpath(post_processing_path(inputs), "bidding_group_total_revenue_commercial.csv")
    if isfile(revenue_file_path)
        for (asset_owner_index, asset_owner_label) in enumerate(asset_owner_label(inputs))
            custom_plot(
                revenue_file_path,
                PlotTimeSeriesStackedMean;
                plot_path = joinpath(plots_path, "bidding_group_total_revenue_$asset_owner_label"),
                agents = labels_per_asset_owner[asset_owner_index],
                title = "$asset_owner_label Revenue",
            )
        end
    end

    # Generation
    # TODO: choose file correctly (after post-processing PR)
    # TODO: sum over segment dimension
    generation_output_file = joinpath(output_path(inputs), "bidding_group_generation_ex_post_physical_period_$(inputs.args.period).csv")
    generation_post_processing_file = joinpath(post_processing_path(inputs), "bidding_group_generation_ex_post_physical.csv")
    generation_file_path = isfile(generation_output_file) ? generation_output_file : generation_post_processing_file
    if isfile(generation_file_path)
        for (asset_owner_index, asset_owner_label) in enumerate(asset_owner_label(inputs))
            custom_plot(
                generation_file_path,
                PlotTimeSeriesStackedMean;
                plot_path = joinpath(plots_path, "bidding_group_generation_$asset_owner_label"),
                agents = labels_per_asset_owner[asset_owner_index],
                title = "$asset_owner_label Generation",
            )
        end
    end

    return nothing
end

function build_ui_case_plots(
    inputs::Inputs,
)
    plots_path = joinpath(output_path(inputs), "plots")

    # Spot price
    spot_price_file_path = joinpath(output_path(inputs), "load_marginal_cost_ex_post_physical_period_$(inputs.args.period).csv")
    if isfile(spot_price_file_path)
        custom_plot(
            spot_price_file_path,
            PlotTimeSeriesMean;
            plot_path = joinpath(plots_path, "spot_price"),
            title = "Spot Price",
        )
    end

    # Generation by technology
    generation_file_path = joinpath(post_processing_path(inputs), "generation.csv")
    if isfile(generation_file_path)
        custom_plot(
            generation_file_path,
            PlotTimeSeriesStackedMean;
            plot_path = joinpath(plots_path, "generation_by_technology"),
            title = "Generation by Technology",
            agents = ["hydro", "thermal", "renewable", "battery_unit"], # Does not include deficit
        )
    end

    # Offer curve
    plot_offer_curve(inputs, plots_path)

    return nothing
end

function build_ui_plots(
    inputs::Inputs,
)
    Log.info("Building UI plots")

    plots_path = joinpath(output_path(inputs), "plots")
    if !isdir(plots_path)
        mkdir(plots_path)
    end

    build_ui_individual_plots(inputs)
    build_ui_case_plots(inputs)

    return nothing
end

function plot_offer_curve(inputs::AbstractInputs, plots_path::String)
    offer_files = get_offer_file_paths(inputs)
    if !isempty(offer_files)
        quantity_offer_file = offer_files[1]
        price_offer_file = offer_files[2]
        
        quantity_data, quantity_metadata = read_timeseries_file(quantity_offer_file)
        price_data, price_metadata = read_timeseries_file(price_offer_file)

        @assert quantity_metadata.number_of_time_series == price_metadata.number_of_time_series "Mismatch between quantity and price offer file columns"
        @assert quantity_metadata.dimension_size == price_metadata.dimension_size "Mismatch between quantity and price offer file dimensions"
        @assert quantity_metadata.labels == price_metadata.labels "Mismatch between quantity and price offer file labels"

        num_labels = quantity_metadata.number_of_time_series
        num_periods, num_scenarios, num_subperiods, num_bid_segments = quantity_metadata.dimension_size
        num_buses = number_of_elements(inputs, Bus)

        # Remove the period dimension
        if num_periods > 1
            # From input files, with all periods
            quantity_data = quantity_data[:, :, :, :, inputs.args.period]
            price_data = price_data[:, :, :, :, inputs.args.period]
        else
            # Or from heuristic bid output files, with a single period
            quantity_data = dropdims(quantity_data, dims = 5)
            price_data = dropdims(price_data, dims = 5)
        end

        for subperiod in 1:num_subperiods
            reshaped_quantity = [Float64[] for bus in 1:num_buses]
            reshaped_price = [Float64[] for bus in 1:num_buses]

            for segment in 1:num_bid_segments
                for label_index in 1:num_labels
                    bus_index = _get_bus_index(quantity_metadata.labels[label_index], bus_label(inputs))
                    # mean across scenarios
                    quantity = mean(quantity_data[label_index, segment, subperiod, :])
                    price = mean(price_data[label_index, segment, subperiod, :])
                    # push point
                    push!(reshaped_quantity[bus_index], quantity)
                    push!(reshaped_price[bus_index], price)
                end
            end

            for bus in 1:num_buses
                sort_order = sortperm(reshaped_price[bus])
                reshaped_quantity[bus] = reshaped_quantity[bus][sort_order]
                reshaped_quantity[bus] = cumsum(reshaped_quantity[bus])
                reshaped_price[bus] = reshaped_price[bus][sort_order]
            end

            quantity_data_to_plot = [Float64[0.0] for bus in 1:num_buses]
            price_data_to_plot = [Float64[0.0] for bus in 1:num_buses]

            for bus in 1:num_buses
                for (quantity, price) in zip(reshaped_quantity[bus], reshaped_price[bus])
                    # old point
                    push!(quantity_data_to_plot[bus], quantity_data_to_plot[bus][end])
                    push!(price_data_to_plot[bus], price)
                    # new point
                    push!(quantity_data_to_plot[bus], quantity)
                    push!(price_data_to_plot[bus], price)

                end
            end

            configs = Vector{Config}()

            title = "Offer Curve - Subperiod $subperiod"
            for bus in 1:num_buses
                push!(
                    configs,
                    Config(;
                        x = quantity_data_to_plot[bus],
                        y = price_data_to_plot[bus],
                        name = bus_label(inputs, bus),
                        line = Dict("color" => _get_plot_color(bus)),
                        type = "line",
                    ),
                )
            end

            main_configuration = Config(;
                title = title,
                xaxis = Dict("title" => "Quantity [MWh]"),
                yaxis = Dict("title" => "Price [\$/MWh]"),
            )

            _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "offer_curve_subperiod_$subperiod.html"))
        end
    end

    return nothing
end

function plot_demand(inputs::AbstractInputs, plots_path::String)
    demand_file = if read_ex_ante_demand_file(inputs)
        joinpath(path_case(inputs), demand_unit_demand_ex_ante_file(inputs))
    elseif read_ex_post_demand_file(inputs)
        joinpath(path_case(inputs), demand_unit_demand_ex_post_file(inputs))
    else
        ""
    end
    demand_file *= InterfaceCalls.timeseries_file_extension(demand_file)
    if isfile(demand_file)
        data, metadata = read_timeseries_file(demand_file)
        # Average across subscenarios for ex-post file
        data_reshaped = if !read_ex_ante_demand_file(inputs)
            dropdims(mean(data_reshaped, dims = 3), dims = 3)
        else
            data
        end
        data_reshaped = merge_period_subperiod(data_reshaped)
        # Sum all units
        total_demand = zeros(1, size(data_reshaped)[2:end]...)
        for demand_index in 1:number_of_elements(inputs, DemandUnit)
            total_demand[1, :, :] .+= data_reshaped[demand_index, :, :] * demand_unit_max_demand(inputs, demand_index)
        end
        demand_to_plot, names = agent_quantile_in_scenarios(PlotTimeSeriesQuantiles, total_demand, ["Total demand"])

        time_series_length = size(demand_to_plot, 2)

        configs = Vector{Config}()
        plot_ticks, hover_ticks = _get_plot_ticks(demand_to_plot, size(data)[end], initial_date_time(inputs), time_series_step(inputs))
        unit = "MW"
        p10_idx = 1
        p50_idx = 2
        p90_idx = 3
        push!(configs,
            Config(;
                x = vcat(1:time_series_length, time_series_length:-1:1),
                y = vcat(demand_to_plot[p10_idx, :], reverse(demand_to_plot[p90_idx, :])),
                name = names[1] * " (P10 - P90)",
                fill = "toself",
                line = Dict("color" => "transparent"),
                fillcolor = _get_plot_color(1; transparent = true),
                type = "line",
                text = hover_ticks,
                hovertemplate = "%{y} $unit",
                hovermode = "closest",
            ))
        push!(configs,
            Config(;
                x = 1:time_series_length,
                y = demand_to_plot[p50_idx, :],
                name = names[1] * " (P50)",
                line = Dict("color" => _get_plot_color(1)),
                type = "line",
                text = hover_ticks,
                hovertemplate = "%{y} $unit<br>%{text}",
            ))
    
        main_configuration = Config(;
            title = "Total demand",
            xaxis = Dict(
                "title" => "Period",
                "tickmode" => "array",
                "tickvals" => [i for i in eachindex(plot_ticks)],
                "ticktext" => plot_ticks,
            ),
            yaxis = Dict("title" => unit),
        )
        _save_plot(Plot(configs, main_configuration), joinpath(plots_path, "total_demand.html"))
    end
    return nothing
end
