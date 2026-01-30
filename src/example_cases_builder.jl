#############################################################################
#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

module ExampleCases

import ..IARA

const MAP_OF_CASES = Dict(
    "brasil_8owners_01" => "brasil_8_owners/base_case",
    "boto_base_01" => "case_09/base_case",
    "boto_nohydro_01" => "case_09/nohydro_case",
    "ui_c1" => "case_14/base_case",
    "ui_c2" => "case_14/dual_settlement",
    "ui_c3" => "case_15/renewable",
)

"""
    list_of_available_cases()

Return a list of available cases to be loaded.
"""
function list_of_available_cases()
    return collect(keys(MAP_OF_CASES))
end

function _string_valid_cases_error(valid_cases)
    str = "\n"
    for case in valid_cases
        str *= "    - $(case)\n"
    end
    return str
end

"""
    build_example_case(
        path::AbstractString, 
        case_name::String;
        force::Bool = false,
    )

Build the case with the name `case_name` in the directory `path`. If the directory does not exist, it will be created.
If the directory exists and is not empty, an error will be thrown. The `force` parameter can be used to overwrite
the content of the directory.

the available cases are listed in the function `list_of_available_cases()`.
"""
function build_example_case(path::AbstractString, case_name::String; force::Bool = true)
    # Validate if the case name asked is valid
    valid_cases = list_of_available_cases()
    if !(case_name in valid_cases)
        error(
            "The case name \"$(case_name)\" is not valid. Please, choose one of the following: $(_string_valid_cases_error(valid_cases))",
        )
    end

    # Create the path if it does not exist yet
    if !isdir(path)
        mkdir(path)
    else
        if force
            rm(path; recursive = true)
            mkdir(path)
        else
            files = readdir(path)
            if !isempty(files)
                error(
                    "The directory $(realpath(path)) is not empty. Please, remove " *
                    "its content before proceeding or call the function `build_example_case` " *
                    "with the argument `force = true`.",
                )
            end
        end
    end

    println("Building case \"$(case_name)\" in \"$(realpath(path))\"")

    # All test cases assume that there is a PATH variable that points to the directory where the case is going 
    # to be build. This could be harmful if the user has a PATH variable in the environment.
    global PATH = path

    test_case_dir = joinpath(dirname(@__DIR__), "test")
    case_directory = MAP_OF_CASES[case_name]
    splitted_case_directory = split(case_directory, "/")
    case_base_dir, case_directory = string(splitted_case_directory[1]), string(splitted_case_directory[2])

    build_case_path = joinpath(test_case_dir, case_base_dir, "base_case", "build_case.jl")
    modify_case_path = joinpath(test_case_dir, case_base_dir, case_directory, "modify_case.jl")

    # Copy all file *.csv, *.json, *.toml from the base_case to the new case path
    for file in readdir(joinpath(test_case_dir, case_base_dir, "base_case"))
        if endswith(file, r"(.csv|.json|.toml)$") || isequal(file, "parp")
            cp(
                joinpath(test_case_dir, case_base_dir, "base_case", file),
                joinpath(path, file),
            )
        end
    end

    include(build_case_path)
    if isfile(modify_case_path)
        include(modify_case_path)
    end

    return nothing
end

end # module
