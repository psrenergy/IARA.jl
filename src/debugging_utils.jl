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
    node::SDDP.Node,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    t::Integer,
    scen::Integer,
    subscenario::Integer,
)
    if is_market_clearing(inputs)
        function fix_integer_variables_from_previous_problem_hook(model::JuMP.Model)
            fix_discrete_variables_from_previous_problem!(inputs, run_time_options, model, t, scen)
            optimize!(model; ignore_optimize_hook = true)
            return nothing
        end

        function fix_integer_variables_hook(model::JuMP.Model)
            optimize!(model; ignore_optimize_hook = true)
            undo = fix_discrete_variables(model)
            optimize!(model; ignore_optimize_hook = true)
            return nothing
        end
    end

    function relax_integrality_hook(model::JuMP.Model)
        relax_integrality(model)
        optimize!(model; ignore_optimize_hook = true)
        return nothing
    end

    if inputs.args.write_lp
        filename = lp_filename(inputs, run_time_options, t, scen, subscenario)
        function write_lp_hook(model)
            optimize!(model; ignore_optimize_hook = true)
            optimizer = JuMP.backend(model).optimizer.model.optimizer
            # We make this statement because when using ParametricOptInterface the 
            # written might not pass all parameters to the file.
            # Writing directly from the lower leve API will ensure that exactly the 
            # model being solved is written.
            _pass_names_to_solver(optimizer)
            HiGHS.Highs_writeModel(optimizer.inner, filename)
            return nothing
        end

        if JuMP.solver_name(node.subproblem) != "Parametric Optimizer with HiGHS attached"
            SDDP.write_subproblem_to_file(node, filename)
        end
    else
        function treat_infeasibilities(model)
            JuMP.optimize!(model; ignore_optimize_hook = true)
            status = JuMP.termination_status(model)
            if status == MOI.INFEASIBLE
                optimizer = JuMP.backend(model).optimizer.model.optimizer
                filename = lp_filename(inputs, run_time_options, t, scen, subscenario)

                # We make this statement because when using ParametricOptInterface the 
                # written might not pass all parameters to the file.
                # Writing directly from the lower leve API will ensure that exactly the 
                # model being solved is written.
                _pass_names_to_solver(optimizer)
                HiGHS.Highs_writeModel(optimizer.inner, filename)
            end
            return nothing
        end
    end

    function all_optimize_hooks(model)
        if is_market_clearing(inputs)
            if clearing_has_fixed_binary_variables(inputs, run_time_options)
                fix_integer_variables_hook(model)
            elseif clearing_has_fixed_binary_variables_from_previous_problem(inputs, run_time_options)
                fix_integer_variables_from_previous_problem_hook(model)
            elseif clearing_has_linearized_binary_variables(inputs, run_time_options)
                relax_integrality_hook(model)
            end
        end
        if !use_binary_variables(inputs)
            relax_integrality_hook(model)
        end
        if inputs.args.write_lp
            if JuMP.solver_name(node.subproblem) == "Parametric Optimizer with HiGHS attached"
                write_lp_hook(model)
            end
        else
            treat_infeasibilities(model)
        end
        return nothing
    end
    set_optimize_hook(node.subproblem, all_optimize_hooks)

    return
end

"""
    lp_filename(inputs::Inputs, run_time_options::RunTimeOptions, t::Integer, scen::Integer, subscenario::Integer)

Return the filename to write the lp file.
"""
function lp_filename(inputs::Inputs, run_time_options::RunTimeOptions, t::Integer, scen::Integer, subscenario::Integer)
    if run_mode(inputs) == RunMode.TRAIN_MIN_COST
        return joinpath(path_case(inputs), "t$(t)_s$(scen)_train_min_cost.lp")
    elseif run_mode(inputs) == RunMode.PRICE_TAKER_BID ||
           run_mode(inputs) == RunMode.STRATEGIC_BID
        return joinpath(path_case(inputs), "t$(t)_s$(scen)_a$(run_time_options.asset_owner_index).lp")
    else # Clearing
        if is_ex_post_problem(run_time_options)
            return joinpath(
                path_case(inputs),
                "$(run_time_options.clearing_model_subproblem)_t$(t)_s$(scen)_ss$(subscenario).lp",
            )
        else
            return joinpath(path_case(inputs), "$(run_time_options.clearing_model_subproblem)_t$(t)_s$(scen).lp")
        end
    end
end

function _pass_names_to_solver(optimizer; warn::Bool = true)
    _pass_variable_names_to_solver(optimizer; warn = warn)
    _pass_constraint_names_to_solver(optimizer; warn = warn)
    return
end

function _pass_variable_names_to_solver(optimizer; warn::Bool = true)
    max_name_length = 64
    n = length(optimizer.variable_info)
    if n == 0
        return
    end
    names = String["C$i" for i in 1:n]
    duplicate_check = Set{String}()
    for info in values(optimizer.variable_info)
        if isempty(info.name)
            continue
        elseif length(info.name) > max_name_length
            if warn
                @warn(
                    "Skipping variable name because it is longer than " *
                    "$max_name_length characters: $(info.name)",
                )
            end
        elseif info.name in duplicate_check
            if warn
                @warn("Skipping duplicate variable name $(info.name)")
            end
        else
            names[info.column+1] = info.name
            push!(duplicate_check, info.name)
        end
    end
    for (col, name) in enumerate(names)
        HiGHS.Highs_passColName(optimizer.inner, col - 1, name)
    end
    return
end

function _pass_constraint_names_to_solver(optimizer; warn::Bool = true)
    max_name_length = 64
    n = length(optimizer.affine_constraint_info)
    if n == 0
        return
    end
    names = String["R$i" for i in 1:n]
    duplicate_check = Set{String}()
    for info in values(optimizer.affine_constraint_info)
        if isempty(info.name)
            continue
        elseif length(info.name) > max_name_length
            if warn
                @warn(
                    "Skipping constraint name because it is longer than " *
                    "$max_name_length characters: $(info.name)",
                )
            end
        elseif info.name in duplicate_check
            if warn
                @warn("Skipping duplicate constraint name $(info.name)")
            end
        else
            names[info.row+1] = info.name
            push!(duplicate_check, info.name)
        end
    end
    for (row, name) in enumerate(names)
        HiGHS.Highs_passRowName(optimizer.inner, row - 1, name)
    end
    return
end
