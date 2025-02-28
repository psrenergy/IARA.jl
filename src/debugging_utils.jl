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
