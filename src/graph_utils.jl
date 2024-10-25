#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function build_graph(inputs::Inputs; current_period::Union{Nothing, Int} = nothing)
    # For the market clearing problem type, we simulate each period individually
    if run_mode(inputs) == Configurations_RunMode.MARKET_CLEARING
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
    p = edge_probability(inputs)

    # Add edges
    SDDP.add_edge(graph, 0 => 1, 1.0)
    for node in nodes(inputs)
        if node == number_of_nodes(inputs)
            next_node = 1
        else
            next_node = node + 1
        end

        SDDP.add_edge(graph,
            node => next_node,
            p,
        )
    end

    # Assert problem terminates
    outgoing_probabilities = [sum(child[2] for child in node) for node in values(graph.nodes)]
    @assert !all(outgoing_probabilities .== 1.0)

    return graph
end

function edge_probability(inputs::Inputs)
    # This implies that the cyclic graph represents exactly one year
    yearly_probability = 1 / (1 + yearly_discount_rate(inputs))
    node_probability = yearly_probability^(1 / number_of_nodes(inputs))
    return node_probability
end
