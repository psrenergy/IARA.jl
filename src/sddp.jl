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
    run_time_options::RunTimeOptions,
)
    optimizer = optimizer_with_attributes(
        () -> POI.Optimizer(inputs.args.optimizer()),
        MOI.Silent() => true,
    )

    policy_graph = SDDP.PolicyGraph(
        build_graph(inputs);
        sense = :Min,
        lower_bound = get_lower_bound(inputs, run_time_options),
        optimizer = optimizer,
    ) do subproblem, node
        update_time_series_views_from_external_files!(inputs; period = node, scenario = 1)
        update_time_series_from_db!(inputs, node)
        update_segments_profile_dimensions!(inputs, node)

        sp_model = build_subproblem_model(
            inputs,
            run_time_options,
            node;
            jump_model = subproblem,
        )

        scenario_combinations = Tuple{Int, Int, Int, Int}[]
        for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
            push!(scenario_combinations, (scenario, subscenario, node, scenario))
        end

        SDDP.parameterize(
            sp_model.jump_model,
            scenario_combinations,
        ) do (scenario, subscenario, simulation_period, simulation_trajectory)
            update_time_series_views_from_external_files!(inputs; period = node, scenario)
            update_time_series_from_db!(inputs, node)
            model_action(
                sp_model,
                inputs,
                run_time_options,
                simulation_period,
                simulation_trajectory,
                scenario,
                subscenario,
                SubproblemUpdate,
            )
            set_custom_hook(subproblem, inputs, run_time_options, node, scenario, subscenario)
            return
        end
    end

    model = ProblemModel(; policy_graph = policy_graph)

    return model
end

function train_model!(model::ProblemModel, inputs::Inputs)
    SDDP.train(
        model.policy_graph;
        stopping_rules = [
            SDDP.SimulationStoppingRule(),
        ],
        iteration_limit = train_mincost_iteration_limit(inputs),
        time_limit = train_mincost_time_limit_sec(inputs),
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
    simulation_scheme = build_simulation_scheme(model, inputs, run_time_options; current_period)

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
    model::ProblemModel,
    inputs::Inputs,
    run_time_options::RunTimeOptions;
    current_period::Union{Nothing, Int} = nothing,
)
    simulation_scheme =
        Array{Array{Tuple{Int, Tuple{Int, Int, Int, Int}}, 1}, 1}(
            undef,
            number_of_scenarios(inputs) * number_of_subscenarios(inputs, run_time_options),
        )

    scheme_index = 0
    if linear_policy_graph(inputs)
        periods_to_simulate = if isnothing(current_period)
            1:number_of_periods(inputs)
        else
            [current_period]
        end
        for scenario in scenarios(inputs), subscenario in subscenarios(inputs, run_time_options)
            scheme_index += 1
            simulation_scheme[scheme_index] =
                [(t, (scenario, subscenario, t, scenario)) for t in periods_to_simulate]
        end
    else
        simulation_scheme = seasonal_simulation_scheme(inputs, run_time_options; current_period)
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
    fcf_cuts_filepath = fcf_cuts_path(inputs)
    if !isfile(fcf_cuts_filepath)
        error("FCF cuts file not found: $fcf_cuts_filepath")
    end

    # When current_period is provided, we read the cuts for that period only
    if current_period !== nothing
        function current_period_node_name_parser(::Type{Int}, name::String)
            node = parse(Int, name)
            if node != current_period
                return nothing
            else
                return node
            end
        end
        SDDP.read_cuts_from_file(
            model.policy_graph,
            fcf_cuts_filepath;
            node_name_parser = current_period_node_name_parser,
        )
        return model
    end

    # Otherwise, for linear policy graphs, we read the cuts for all periods
    if linear_policy_graph(inputs)
        function all_periods_node_name_parser(::Type{Int}, name::String)
            return parse(Int, name)
        end

        SDDP.read_cuts_from_file(model.policy_graph, fcf_cuts_filepath; node_name_parser = all_periods_node_name_parser)
        return model
    end

    # If we got here, we need to read all nodes for cyclic policy graphs
    number_of_years_in_simulation = ceil(number_of_periods(inputs) / number_of_nodes(inputs))
    for year in 1:number_of_years_in_simulation
        policy_node_to_simulation_node = (year - 1) * number_of_nodes(inputs)
        @nospecialize(function node_name_parser(::Type{Int}, name::String)
            return parse(Int, name) + policy_node_to_simulation_node
        end)
        SDDP.read_cuts_from_file(model.policy_graph, fcf_cuts_filepath; node_name_parser)
    end

    return model
end

"""
    set_custom_hook(
        node::SDDP.Node,
        inputs::Inputs,
        t::Integer,
        scen::Integer,
        subscenario::Integer,
    )

Set hooks to write lps to the file if user asks to write lps or if the model is infeasible.
Also, set hooks to fix integer variables from previous problem, fix integer variables, and relax integrality.
"""
function set_custom_hook(
    subproblem::JuMP.Model,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    t::Integer,
    scen::Integer,
    subscenario::Integer,
)
    function fix_integer_variables_from_previous_problem_hook(model::JuMP.Model)
        fix_discrete_variables_from_previous_problem!(inputs, run_time_options, model, t, scen)
        optimize!(model; ignore_optimize_hook = true)
        return nothing
    end

    function bellman_term_hook(model::JuMP.Model)
        # This is the hook to be called at market clearing to make a tiebreaker weight
        # to the fcf.
        if use_fcf_in_clearing(inputs) && construction_type(inputs, run_time_options) ==  Configurations_ConstructionType.HYBRID &&
            clearing_has_state_variables(inputs, run_time_options)
            node = SDDP.get_node(model)
            bellman_term = SDDP.bellman_term(node.bellman_function)
            JuMP.set_objective_coefficient(model, bellman_term, market_clearing_tiebreaker_weight(inputs))
        end
        return nothing
    end

    function fix_integer_variables_hook(model::JuMP.Model)
        # On min cost and other we can use it as an SDDiP.
        # On market clearing we would like to solve, fix and 
        # only then solve the linear version to get the duals
        if is_market_clearing(inputs)
            optimize!(model; ignore_optimize_hook = true)
            undo = fix_discrete_variables(model)
            optimize!(model; ignore_optimize_hook = true)
        else
            optimize!(model; ignore_optimize_hook = true)
        end
        return nothing
    end

    function relax_integrality_hook(model::JuMP.Model)
        relax_integrality(model)
        optimize!(model; ignore_optimize_hook = true)
        return nothing
    end

    # Definition of what should be the name of the lp file in case we wish to write it.
    lp_file = lp_filename(inputs, run_time_options, t, scen, subscenario)
    function write_lp_hook(model::JuMP.Model, filename::String)
        return JuMP.write_to_file(model, filename)
    end

    function treat_infeasibilities_hook(model::JuMP.Model, filename::String)
        status = JuMP.termination_status(model)
        if JuMP.termination_status(model) == MOI.INFEASIBLE
            try
                compute_conflict!(model)
                if get_attribute(model, MOI.ConflictStatus()) == MOI.CONFLICT_FOUND
                    list_of_conflicting_constraints = ConstraintRef[]
                    for (F, S) in list_of_constraint_types(model)
                        for con in all_constraints(model, F, S)
                            if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
                                push!(list_of_conflicting_constraints, con)
                            end
                        end
                    end
                    if length(list_of_conflicting_constraints) > 0
                        conflict_file_path = filename * ".iis"
                        @info("Conflicting constraints found! Writing to file: $conflict_file_path")
                        # Write the conflicting constraints to a file
                        open(conflict_file_path, "w") do io
                            for con in list_of_conflicting_constraints
                                println(io, con)
                            end
                        end
                    end
                else
                    @info("No conflicting constraints found.")
                end
            catch e
                @info("Model was infeasible but unable to compute conflict due to: $e")
                @info("Writing the model to file: $filename")
                JuMP.write_to_file(model, filename)
            end
            error("Model is infeasible.")
        end
        return nothing
    end

    function all_optimize_hooks(model)
        if integer_variable_representation(inputs, run_time_options) ==
           Configurations_IntegerVariableRepresentation.CALCULATE_NORMALLY
            fix_integer_variables_hook(model)
        elseif integer_variable_representation(inputs, run_time_options) ==
               Configurations_IntegerVariableRepresentation.FROM_EX_ANTE_PHYSICAL
            fix_integer_variables_from_previous_problem_hook(model)
        elseif integer_variable_representation(inputs, run_time_options) ==
               Configurations_IntegerVariableRepresentation.LINEARIZE
            relax_integrality_hook(model)
        else
            error("Invalid integer variable representation.")
        end

        bellman_term_hook(model)

        # Optimize the model
        JuMP.optimize!(model; ignore_optimize_hook = true)

        if inputs.args.write_lp
            write_lp_hook(model, lp_file)
        end
        treat_infeasibilities_hook(model, lp_file)
        return nothing
    end
    set_optimize_hook(subproblem, all_optimize_hooks)

    return
end
