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
        asset_owner_index::Integer,
    )

Set hooks to write lps to the file if user asks to write lps or if the model is infeasible.
"""
function set_custom_hook(
    node::SDDP.Node,
    inputs::Inputs,
    run_time_options::RunTimeOptions,
    t::Integer,
    scen::Integer,
)
    if inputs.args.write_lp
        filename = lp_filename(inputs, run_time_options, t, scen)
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

        if JuMP.solver_name(node.subproblem) == "Parametric Optimizer with HiGHS attached"
            set_optimize_hook(node.subproblem, write_lp_hook)
        else
            SDDP.write_subproblem_to_file(node, filename * ".lp")
        end
    else
        function treat_infeasibilities(model)
            JuMP.optimize!(model; ignore_optimize_hook = true)
            status = JuMP.termination_status(model)
            if status == MOI.INFEASIBLE
                optimizer = JuMP.backend(model).optimizer.model.optimizer
                filename = lp_filename(inputs, run_time_options, t, scen)

                # We make this statement because when using ParametricOptInterface the 
                # written might not pass all parameters to the file.
                # Writing directly from the lower leve API will ensure that exactly the 
                # model being solved is written.
                _pass_names_to_solver(optimizer)
                HiGHS.Highs_writeModel(optimizer.inner, filename * ".lp")
            end
            return nothing
        end

        set_optimize_hook(node.subproblem, treat_infeasibilities)
    end
    return
end

function lp_filename(inputs::Inputs, run_time_options::RunTimeOptions, t::Integer, scen::Integer)
    if run_mode(inputs) == Configurations_RunMode.PRICE_TAKER_BID ||
       run_mode(inputs) == Configurations_RunMode.STRATEGIC_BID
        return joinpath(path_case(inputs), "t$(t)_s$(scen)_a$(run_time_options.asset_owner_index).lp")
    else
        return joinpath(path_case(inputs), "t$(t)_s$(scen).lp")
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
