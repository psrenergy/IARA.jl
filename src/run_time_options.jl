#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

@kwdef struct RunTimeOptions
    asset_owner_index::Int = PSRDatabaseSQLite._psrdatabasesqlite_null_value(Int)
    nash_equilibrium_iteration::Int = 0
    nash_equilibrium_initialization::Bool = false
    clearing_model_subproblem::Union{RunTime_ClearingSubproblem.T, Nothing} = nothing
    clearing_integer_variables_in_model::Vector{Symbol} = Symbol[]
    force_all_subscenarios::Bool = false
    is_reference_curve::Bool = false
end

function iara_log(inputs::AbstractInputs, run_time_options::RunTimeOptions)
    return @info(
        Printf.@sprintf(" %-20s %-20s %-20s %-20s",
            enum_name_to_string(run_time_options.clearing_model_subproblem),
            enum_name_to_string(construction_type(inputs, run_time_options)),
            enum_name_to_string(integer_variable_representation(inputs, run_time_options)),
            enum_name_to_string(network_representation(inputs, run_time_options)),
        )
    )
end
