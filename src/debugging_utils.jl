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
function lp_filename(
    inputs::Inputs, 
    run_time_options::RunTimeOptions, 
    t::Integer, 
    scen::Integer, 
    subscenario::Integer;
    suffix::String = "",
)
    ext = isempty(suffix) ? ".lp" : "_$suffix.lp"
    if is_reference_curve(inputs, run_time_options)
        return joinpath(path_case(inputs), "t$(t)_s$(scen)_reference_curve$(ext)")
    elseif run_mode(inputs) == RunMode.TRAIN_MIN_COST
        return joinpath(path_case(inputs), "t$(t)_s$(scen)_train_min_cost$(ext)")
    elseif iterate_nash_equilibrium(inputs) && is_current_asset_owner_bidder(inputs, run_time_options)
        return joinpath(
            path_case(inputs),
            "NASH_ITERATION_" * string(nash_equilibrium_iteration(inputs, run_time_options)) *
            "_t$(t)_s$(scen)_a$(run_time_options.asset_owner_index)$(ext)",
        )
    else # Clearing
        nash_eq_iteration = nash_equilibrium_iteration(inputs, run_time_options)
        nash_eq_string = if nash_eq_iteration > 0
            "NASH_ITERATION_$(nash_eq_iteration)_"
        else
            ""
        end
        if is_ex_post_problem(run_time_options)
            return joinpath(
                path_case(inputs),
                nash_eq_string * "$(run_time_options.clearing_model_subproblem)_t$(t)_s$(scen)_ss$(subscenario)$(ext)",
            )
        else
            return joinpath(
                path_case(inputs),
                nash_eq_string * "$(run_time_options.clearing_model_subproblem)_t$(t)_s$(scen)$(ext)",
            )
        end
    end
end
