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
    build_graph(inputs::Inputs; current_period::Union{Nothing, Int} = nothing)

Builds a graph based on the inputs.
"""
function build_graph(inputs::Inputs; current_period::Union{Nothing, Int} = nothing)
    # For the market clearing problem type, we simulate each period individually
    if run_mode(inputs) == RunMode.MARKET_CLEARING
        if isnothing(current_period)
            error("current_period must be provided for the MARKET_CLEARING run mode")
        end
        graph = SDDP.Graph(0)
        SDDP.add_node(graph, current_period)
        SDDP.add_edge(graph, 0 => current_period, 1.0)
        return graph
    end
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
    if policy_graph_type(inputs) == Configurations_PolicyGraphType.CYCLIC_WITH_FIXED_ROOT
        SDDP.add_edge(graph, 0 => 1, 1.0)
    elseif policy_graph_type(inputs) == Configurations_PolicyGraphType.CYCLIC_WITH_DISTRIBUTED_ROOT
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
