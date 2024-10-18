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
    clearing_model_procedure::Union{RunTime_ClearingProcedure.T, Nothing} = nothing
    clearing_integer_variables_in_model::Vector{Symbol} = Symbol[]
end
