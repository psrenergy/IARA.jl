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
    post_processing(inputs)

Run post-processing routines.
"""
function post_processing(inputs)
    println("Running post-processing routines")
    gather_outputs_separated_by_asset_owners(inputs)
    if run_mode(inputs) == Configurations_RunMode.CENTRALIZED_OPERATION
        post_processing_generation(inputs)
    end
    return nothing
end

function read_timeseries_file_in_outputs(filename, inputs)
    output_path = joinpath(path_case(inputs), "outputs")
    filepath_csv = joinpath(output_path, filename * ".csv")
    filepath_quiv = joinpath(output_path, filename * ".quiv")
    filepath = isfile(filepath_quiv) ? filepath_quiv : filepath_csv
    return read_timeseries_file(filepath)
end
