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
    build_graph(inputs::Inputs)

Builds a graph based on the inputs.
"""
function build_graph(inputs::Inputs)
    if linear_policy_graph(inputs)
        graph_size = number_of_periods(inputs)
        return SDDP.LinearGraph(graph_size)
    end

    # Create graph
    graph = SDDP.Graph(0)

    # Add nodes
    for node in nodes(inputs)
        SDDP.add_node(graph, node)
    end

    # Get edge probabilities
    prob_end = node_termination_probability(inputs)
    prob_repeat = node_repetition_probability(inputs)

    # Edges from root
    if policy_graph_type(inputs) == Configurations_PolicyGraphType.CYCLIC_WITH_NULL_ROOT
        SDDP.add_edge(graph, 0 => 1, 1.0)
    elseif policy_graph_type(inputs) == Configurations_PolicyGraphType.CYCLIC_WITH_SEASON_ROOT
        for node in nodes(inputs)
            SDDP.add_edge(graph, 0 => node, 1.0 / number_of_nodes(inputs))
        end
    else
        error("Policy graph type $(policy_graph_type(inputs)) not supported.")
    end

    # Other edges
    for node in nodes(inputs)
        if node == number_of_nodes(inputs)
            next_node = 1
        else
            next_node = node + 1
        end

        # Edge to self
        SDDP.add_edge(graph,
            node => node,
            (1 - prob_end) * prob_repeat[node],
        )

        # Edge to next node
        SDDP.add_edge(graph,
            node => next_node,
            (1 - prob_end) * (1 - prob_repeat[node]),
        )
    end

    # Assert problem terminates
    outgoing_probabilities = [sum(child[2] for child in node) for node in values(graph.nodes)]
    @assert !all(outgoing_probabilities .== 1.0)

    return graph
end

"""
    node_termination_probability(inputs::Inputs)

Returns the probability that the problem finishes after solving a node's subproblem.
"""
function node_termination_probability(inputs::Inputs)
    subproblem_duration_in_hours = sum(subperiod_duration_in_hours(inputs))
    cycle_non_termination_probability = 1 / (1 + cycle_discount_rate(inputs))
    node_non_termination_probability =
        cycle_non_termination_probability^(subproblem_duration_in_hours / cycle_duration_in_hours(inputs))
    return 1 - node_non_termination_probability
end

"""
    node_repetition_probability(inputs::Inputs)

Returns the probability that the problem repeats a node after solving it's subproblem.
"""
function node_repetition_probability(inputs::Inputs)
    return 1 .- (1 ./ expected_number_of_repeats_per_node(inputs))
end

function create_period_season_map!(
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    model::ProblemModel,
)
    Random.seed!(1234)
    prob_end = node_termination_probability(inputs)
    transition_probability_matrix = zeros(number_of_nodes(inputs), number_of_nodes(inputs))

    for node_idx in nodes(inputs)
        node = model.policy_graph.nodes[node_idx]
        for child in node.children
            transition_probability_matrix[node_idx, child.term] = child.probability / (1 - prob_end)
        end
    end
    @assert all(sum(transition_probability_matrix; dims = 2) .== 1.0)

    # For each trajectory and period, we sample a season, scenario and next_subscenario
    period_season_map = Array{Int, 3}(undef, 3, number_of_scenarios(inputs), number_of_periods(inputs))

    for trajectory in scenarios(inputs)
        # First node
        t = 1
        node = if policy_graph_type(inputs) == Configurations_PolicyGraphType.CYCLIC_WITH_NULL_ROOT
            1
        elseif policy_graph_type(inputs) == Configurations_PolicyGraphType.CYCLIC_WITH_SEASON_ROOT
            rand(1:number_of_nodes(inputs))
        else
            error("Policy graph type $(policy_graph_type(inputs)) not supported.")
        end
        simulation_sample = rand(1:number_of_scenarios(inputs))
        next_subscenario = if number_of_subscenarios(inputs, run_time_options) == 1
            1
        else
            rand(1:number_of_subscenarios(inputs, run_time_options))
        end
        period_season_map[1, trajectory, t] = node
        period_season_map[2, trajectory, t] = simulation_sample
        period_season_map[3, trajectory, t] = next_subscenario
        # Other nodes
        for t in 2:number_of_periods(inputs)
            node = sample(1:number_of_nodes(inputs), Weights(transition_probability_matrix[node, :]))
            simulation_sample = rand(1:number_of_scenarios(inputs))
            next_subscenario = if number_of_subscenarios(inputs, run_time_options) == 1
                1
            else
                rand(1:number_of_subscenarios(inputs, run_time_options))
            end
            period_season_map[1, trajectory, t] = node
            period_season_map[2, trajectory, t] = simulation_sample
            period_season_map[3, trajectory, t] = next_subscenario
        end
    end

    write_timeseries_file(
        joinpath(output_path(inputs), "period_season_map"),
        period_season_map;
        dimensions = ["period", "scenario"],
        labels = ["season", "sample", "next_subscenario"],
        time_dimension = "period",
        dimension_size = [number_of_periods(inputs), number_of_scenarios(inputs)],
        initial_date = initial_date_time(inputs),
        unit = " ",
    )

    inputs.collections.configurations.period_season_map = period_season_map

    return nothing
end

function seasonal_simulation_scheme(
    inputs::Inputs,
    run_time_options::RunTimeOptions;
    current_period::Union{Nothing, Int} = nothing,
)
    simulation_scheme = Array{Array{Tuple{Int, Tuple{Int, Int}}, 1}, 1}(
        undef,
        number_of_scenarios(inputs) * number_of_subscenarios(inputs, run_time_options),
    )

    for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
        trajectory = trajectory_index_from_scenario_subscenario(
            inputs,
            run_time_options,
            scenario,
            subscenario,
        )
        simulation_scheme[trajectory] = []
        periods_to_simulate = if isnothing(current_period)
            1:number_of_periods(inputs)
        else
            [current_period]
        end
        for period in periods_to_simulate
            node = consult_period_season_map(inputs; period, scenario, index = 1)
            push!(simulation_scheme[trajectory], (node, (period, trajectory)))
        end
    end

    return simulation_scheme
end

function subscenario_that_progagates_state_variables_to_next_period(
    inputs::Inputs,
    run_time_options::RunTimeOptions;
    period::Int,
    scenario::Int,
)
    next_subperiod = 1

    if cyclic_policy_graph(inputs) && is_ex_post_problem(run_time_options)
        next_subperiod = consult_period_season_map(inputs; period, scenario, index = 3)
    end

    return next_subperiod
end

function consult_period_season_map(
    inputs::Inputs;
    period::Int,
    scenario::Int,
    index::Union{Nothing, Int} = nothing,
)
    if has_period_season_map_file(inputs)
        update_time_series_views_from_external_files!(inputs; period, scenario)
        node, simulation_sample, next_subperiod = Int.(period_season_map_from_file(inputs).data)
    else
        node, simulation_sample, next_subperiod = period_season_map_cache(inputs; period, scenario)
    end

    map_info = node, simulation_sample, next_subperiod

    if isnothing(index)
        return map_info
    end

    return map_info[index]
end
