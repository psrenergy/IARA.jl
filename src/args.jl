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
    outputs_path::String
    run_mode::RunMode.T
    write_lp::Bool
    plot_outputs::Bool
end

function Args(args::Vector{String})
    parsed_args = parse_commandline(args)
    return Args(
        parsed_args["path"],
        parsed_args["output-path"],
        parse_run_mode(parsed_args["run-mode"]),
        parsed_args["write-lp"],
        parsed_args["plot-results"],
    )
end

function Args(
    path::String,
    run_mode::RunMode.T;
    output_path::String = joinpath(path, "outputs"),
    write_lp::Bool = false,
    plot_outputs::Bool = true,
)
    return Args(
        path,
        output_path,
        run_mode,
        write_lp,
        plot_outputs,
    )
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
    s = ArgParse.ArgParseSettings(;
        prog = "IARA",
    )

    #! format: off
    ArgParse.@add_arg_table! s begin
        "path"
        help = "path to the case inputs"
        arg_type = String
        default = pwd()
        "--output-path", "-o"
        help = "path to the output directory"
        arg_type = String
        default = ""
        "--run-mode"
        help = "run mode"
        arg_type = String
        required = true
        "--write-lp"
        help = "write subproblems to LP files"
        action = :store_true
        "--plot-results", "-o"
        help = "plot results"
        arg_type = Bool
        default = true
    end
    #! format: on
    # dump args into dict
    parsed_args = ArgParse.parse_args(args, s)

    # Possibly fix paths and apply the normpath method
    parsed_args["path"] = finish_path(parsed_args["path"])
    if !isdir(parsed_args["path"])
        error("The directory " * parsed_args["path"] * " does not exist.")
    end

    if !isempty(parsed_args["output-path"])
        parsed_args["output-path"] = finish_path(parsed_args["output-path"])
    else
        parsed_args["output-path"] = joinpath(parsed_args["path"], "outputs")
    end

    return parsed_args
end

function iara_log(args::Args)
    Log.info("   Path: $(realpath(args.path))")
    Log.info("   Output path: $(realpath(args.outputs_path))")
    Log.info("   Run mode: $(args.run_mode)")
    if args.write_lp
        Log.info("   Write .lp files of subproblems: true")
    end
    Log.info("   Plot results: $(args.plot_outputs)")
    return nothing
end
