#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function build_model(
    inputs::Inputs,
    run_time_options::RunTimeOptions;
    current_stage::Union{Nothing, Int} = nothing,
)
    optimizer = optimizer_with_attributes(
        () -> POI.Optimizer(HiGHS.Optimizer()),
        MOI.Silent() => true,
    )

    policy_graph = SDDP.PolicyGraph(
        build_graph(inputs; current_stage);
        sense = :Min,
        lower_bound = get_lower_bound(inputs, run_time_options),
        optimizer = optimizer,
    ) do subproblem, t
        update_time_series_views_from_external_files!(inputs; stage = t, scenario = 1)
        update_time_series_from_db!(inputs, t)
        sp_model = build_subproblem_model(
            inputs,
            run_time_options,
            t;
            jump_model = subproblem,
        )

        scenario_combinations = Tuple{Int, Int}[]
        for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
            push!(scenario_combinations, (scenario, subscenario))
        end

        SDDP.parameterize(sp_model.jump_model, scenario_combinations) do (scenario, subscenario)
            update_time_series_views_from_external_files!(inputs; stage = t, scenario)
            update_time_series_from_db!(inputs, t)
            model_action(sp_model, inputs, run_time_options, scenario, subscenario, SubproblemUpdate)
            set_custom_hook(policy_graph[t], inputs, run_time_options, t, scenario)
            return
        end
    end

    model = ProblemModel(; policy_graph = policy_graph)

    return model
end

function train_model!(model::ProblemModel, inputs::Inputs)
    SDDP.train(
        model.policy_graph;
        stopping_rules = [SDDP.SimulationStoppingRule()],
        time_limit = 300.0,
        iteration_limit = iteration_limit(inputs),
    )

    SDDP.write_cuts_to_file(model.policy_graph, joinpath(output_path(inputs), "cuts.json"))

    return model
end

function simulate(
    model::ProblemModel,
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions;
    current_stage::Union{Nothing, Int} = nothing,
)
    simulation_scheme = build_simulation_scheme(inputs, run_time_options; current_stage)

    simulations = SDDP.simulate(
        # The trained model to simulate.
        model.policy_graph,
        # The number of replications.
        number_of_scenarios(inputs) * number_of_subscenarios(inputs, run_time_options),
        # A list of names to record the values of.
        outputs.list_of_symbols_to_query_from_subproblem;
        sampling_scheme = SDDP.Historical(simulation_scheme),
        custom_recorders = outputs.list_of_custom_recorders_to_query_from_subproblem,
    )

    return SimulationResults(simulations)
end

function build_simulation_scheme(
    inputs::Inputs,
    run_time_options::RunTimeOptions;
    current_stage::Union{Nothing, Int} = nothing,
)
    simulation_scheme =
        Array{Array{Tuple{Int, Tuple{Int, Int}}, 1}, 1}(
            undef,
            number_of_scenarios(inputs) * number_of_subscenarios(inputs, run_time_options),
        )

    scheme_index = 0
    if current_stage !== nothing
        for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
            scheme_index += 1
            simulation_scheme[scheme_index] = [(current_stage, (scenario, subscenario))]
        end
    elseif linear_policy_graph(inputs)
        for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
            scheme_index += 1
            simulation_scheme[scheme_index] = [(t, (scenario, subscenario)) for t in 1:number_of_stages(inputs)]
        end
    else
        for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
            scheme_index += 1
            simulation_scheme[scheme_index] =
                [(mod1(t, number_of_nodes(inputs)), (scenario, subscenario)) for t in 1:number_of_stages(inputs)]
        end
    end

    return simulation_scheme
end

function read_cuts_to_model!(
    model::ProblemModel,
    inputs::Inputs;
    current_stage::Union{Nothing, Int} = nothing,
)
    if !has_fcf_cuts_to_read(inputs)
        error("Attempted to read FCF cuts but no file was provided.")
    end

    # When current_stage is provided, we read the cuts for that stage only
    if current_stage !== nothing
        @nospecialize(function node_name_parser(::Type{Int}, name::String)
            node = parse(Int, name)
            if node != current_stage
                return nothing
            else
                return node
            end
        end)
        SDDP.read_cuts_from_file(model.policy_graph, fcf_cuts_file(inputs); node_name_parser)
        return model
    end

    # Otherwise, for linear policy graphs, we read the cuts for all stages
    if linear_policy_graph(inputs)
        @nospecialize(function node_name_parser(::Type{Int}, name::String)
            return parse(Int, name)
        end)
        SDDP.read_cuts_from_file(model.policy_graph, fcf_cuts_file(inputs); node_name_parser)
        return model
    end

    # If we got here, we need to read all nodes for cyclic policy graphs
    number_of_years_in_simulation = ceil(number_of_stages(inputs) / number_of_nodes(inputs))
    for year in 1:number_of_years_in_simulation
        policy_node_to_simulation_node = (year - 1) * number_of_nodes(inputs)
        @nospecialize(function node_name_parser(::Type{Int}, name::String)
            return parse(Int, name) + policy_node_to_simulation_node
        end)
        SDDP.read_cuts_from_file(model.policy_graph, fcf_cuts_file(inputs); node_name_parser)
    end

    return model
end
