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
    current_period::Union{Nothing, Int} = nothing,
)
    optimizer = optimizer_with_attributes(
        () -> POI.Optimizer(HiGHS.Optimizer()),
        MOI.Silent() => true,
    )

    policy_graph = SDDP.PolicyGraph(
        build_graph(inputs; current_period);
        sense = :Min,
        lower_bound = get_lower_bound(inputs, run_time_options),
        optimizer = optimizer,
    ) do subproblem, t
        update_time_series_views_from_external_files!(inputs; period = t, scenario = 1)
        update_time_series_from_db!(inputs, t)
        update_segments_profile_dimensions!(inputs, t)

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
            if subscenario == 1
                update_time_series_views_from_external_files!(inputs; period = t, scenario)
                update_time_series_from_db!(inputs, t)
            end
            model_action(
                sp_model,
                inputs,
                run_time_options,
                scenario,
                subscenario,
                SubproblemUpdate,
            )
            set_custom_hook(subproblem, inputs, run_time_options, t, scenario, subscenario)
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
        log_file = joinpath(output_path(inputs), "sddp.log"),
    )

    SDDP.write_cuts_to_file(model.policy_graph, joinpath(output_path(inputs), "cuts.json"))

    return model
end

function simulate(
    model::ProblemModel,
    inputs::Inputs,
    outputs::Outputs,
    run_time_options::RunTimeOptions;
    current_period::Union{Nothing, Int} = nothing,
)
    simulation_scheme = build_simulation_scheme(inputs, run_time_options; current_period)

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
    current_period::Union{Nothing, Int} = nothing,
)
    simulation_scheme =
        Array{Array{Tuple{Int, Tuple{Int, Int}}, 1}, 1}(
            undef,
            number_of_scenarios(inputs) * number_of_subscenarios(inputs, run_time_options),
        )

    scheme_index = 0
    if current_period !== nothing
        for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
            scheme_index += 1
            simulation_scheme[scheme_index] = [(current_period, (scenario, subscenario))]
        end
    elseif linear_policy_graph(inputs)
        for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
            scheme_index += 1
            simulation_scheme[scheme_index] = [(t, (scenario, subscenario)) for t in 1:number_of_periods(inputs)]
        end
    else
        for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
            scheme_index += 1
            simulation_scheme[scheme_index] =
                [(mod1(t, number_of_nodes(inputs)), (scenario, subscenario)) for t in 1:number_of_periods(inputs)]
        end
    end

    return simulation_scheme
end

function read_cuts_to_model!(
    model::ProblemModel,
    inputs::Inputs;
    current_period::Union{Nothing, Int} = nothing,
)
    if !has_fcf_cuts_to_read(inputs)
        error("Attempted to read FCF cuts but no file was provided.")
    end

    # Check if the file exists in the case or output directory
    fcf_cuts_path_case = joinpath(path_case(inputs), fcf_cuts_file(inputs))
    fcf_cuts_path_output = joinpath(output_path(inputs), fcf_cuts_file(inputs))
    fcf_cuts_path = isfile(fcf_cuts_path_case) ? fcf_cuts_path_case : fcf_cuts_path_output

    # When current_period is provided, we read the cuts for that period only
    if current_period !== nothing
        @nospecialize(function node_name_parser(::Type{Int}, name::String)
            node = parse(Int, name)
            if node != current_period
                return nothing
            else
                return node
            end
        end)
        SDDP.read_cuts_from_file(model.policy_graph, fcf_cuts_path; node_name_parser)
        return model
    end

    # Otherwise, for linear policy graphs, we read the cuts for all periods
    if linear_policy_graph(inputs)
        function node_name_parser(::Type{Int}, name::String)
            return parse(Int, name)
        end

        SDDP.read_cuts_from_file(model.policy_graph, fcf_cuts_path; node_name_parser)
        return model
    end

    # If we got here, we need to read all nodes for cyclic policy graphs
    number_of_years_in_simulation = ceil(number_of_periods(inputs) / number_of_nodes(inputs))
    for year in 1:number_of_years_in_simulation
        policy_node_to_simulation_node = (year - 1) * number_of_nodes(inputs)
        @nospecialize(function node_name_parser(::Type{Int}, name::String)
            return parse(Int, name) + policy_node_to_simulation_node
        end)
        SDDP.read_cuts_from_file(model.policy_graph, fcf_cuts_path; node_name_parser)
    end

    return model
end
