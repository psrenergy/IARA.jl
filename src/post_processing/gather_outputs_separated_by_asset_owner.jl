#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

function gather_outputs_separated_by_asset_owners(inputs::Inputs)
    outputs_dir = output_path(inputs)
    # Query all files that end with _asset_owner_1, _asset_owner_2, etc.
    asset_owner_files = filter(x -> occursin(r"_asset_owner_\d+", x), readdir(outputs_dir))

    # Separate the file by output group
    files_of_output_group = Dict{String, Vector{String}}()
    for file in asset_owner_files
        output_group = split(file, "_asset_owner_")[1]
        if haskey(files_of_output_group, output_group)
            push!(files_of_output_group[output_group], file)
        else
            files_of_output_group[output_group] = [file]
        end
    end

    for (output_group, files) in files_of_output_group
        gathered_file = joinpath(outputs_dir, output_group)
        impl = get_implementation_of_a_list_of_files(files)
        separated_files = [joinpath(outputs_dir, file) for file in files]
        # Filter the separaed files by the header
        toml_of_separated_files = filter(x -> occursin(r"\.toml", x), separated_files)
        # Remove extension from toml in separated files
        separated_files_without_extension = [replace(file, ".toml" => "") for file in toml_of_separated_files]
        Quiver.merge(gathered_file, separated_files_without_extension, impl; digits = 6)
    end

    # remove the separated files
    for (_, files) in files_of_output_group
        for file in files
            rm(joinpath(outputs_dir, file); force = true)
        end
    end

    return nothing
end

function get_implementation_of_a_list_of_files(files::Vector{String})
    # This assumes that all files have the same extension
    for file in files
        if occursin(r"\.csv", file)
            return Quiver.csv
        elseif occursin(r"\.quiv", file)
            return Quiver.binary
        end
    end
end
