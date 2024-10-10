#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

mutable struct Args
    path::String
    write_lp::Bool
    function Args(args::Vector{String})
        parsed_args = parse_commandline(args)
        return new(
            parsed_args["path"],
            parsed_args["write-lp"],
        )
    end
end

function finish_path(path::String)
    if isempty(path)
        return path
    end
    if isfile(path)
        return normpath(path)
    end
    if Sys.islinux() && path[end] != '/'
        return normpath(path * "/")
    elseif Sys.iswindows() && path[end] != '\\'
        return normpath(path * "\\")
    else
        return normpath(path)
    end
end

function parse_commandline(args)
    s = ArgParse.ArgParseSettings()

    #! format: off
    ArgParse.@add_arg_table! s begin
        "path"
        help = "path to the case inputs"
        arg_type = String
        default = pwd()
        "--write-lp"
        help = "write subproblems to LP files"
        action = :store_true
    end
    #! format: on
    # dump args into dict
    parsed_args = ArgParse.parse_args(args, s)

    # Possibly fix paths and apply the normpath method
    parsed_args["path"] = finish_path(parsed_args["path"])
    if !isdir(parsed_args["path"])
        error("The directory " * parsed_args["path"] * " does not exist.")
    end

    return parsed_args
end
