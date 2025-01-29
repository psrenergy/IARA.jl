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
    delete_output_folder_before_execution::Bool
    run_mode::RunMode.T
    write_lp::Bool
    plot_outputs::Bool
    # period is only used in the SINGLE_PERIOD_MARKET_CLEARING run mode
    # its value should be -1 in all other cases
    period::Int
end

function Args(args::Vector{String})
    parsed_args = parse_commandline(args)
    run_mode = parse_run_mode(parsed_args["run-mode"])
    period = parsed_args["period"]::Int
    return Args(
        parsed_args["path"],
        parsed_args["output-path"],
        parsed_args["delete-output-folder-before-execution"],
        run_mode,
        parsed_args["write-lp"],
        parsed_args["plot-results"],
        period,
    )
end

function Args(
    path::String,
    run_mode::RunMode.T;
    output_path::String = joinpath(path, "outputs"),
    delete_output_folder_before_execution::Bool = false,
    write_lp::Bool = false,
    plot_outputs::Bool = true,
    period::Int = -1,
)
    if run_mode == RunMode.SINGLE_PERIOD_MARKET_CLEARING && period <= 0
        error(
            "When running in the SINGLE_PERIOD_MARKET_CLEARING mode, " *
            "the period must be greater than 0. Got period = $period.",
        )
    end
    absolute_output_path = if isabspath(output_path)
        output_path
    else
        joinpath(path, output_path)
    end
    return Args(
        path,
        absolute_output_path,
        delete_output_folder_before_execution,
        run_mode,
        write_lp,
        plot_outputs,
        period,
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
        "--output-path"
        help = "path to the output directory"
        arg_type = String
        default = ""
        "--delete-output-folder-before-execution"
        help = "delete the output folder before execution"
        arg_type = Bool
        default = false
        "--run-mode"
        help = "run mode"
        arg_type = String
        required = true
        "--write-lp"
        help = "write subproblems to LP files"
        action = :store_true
        "--plot-results"
        help = "plot results"
        arg_type = Bool
        default = true
        "--period"
        help = "period for SINGLE_PERIOD_MARKET_CLEARING run mode"
        arg_type = Int
        default = -1
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
