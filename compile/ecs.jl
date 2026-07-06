import Pkg
Pkg.activate(@__DIR__)

for s in 1:10
    try
        Pkg.instantiate()
        break
    catch e
        s == 10 ? rethrow(e) : sleep(s)
    end
end

using ArgParse
using CD

function main(args::Vector{String})
    #! format: off
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--development_stage"
        nargs = '?'
        constant = "Stable"
        default = "Stable"
        "--version_suffix"
        nargs = '?'
        constant = ""
        default = ""
        "--overwrite"
        nargs = '?'
        constant = false
        default = false
        eval_arg = true
        "--os"
        arg_type = String
        "--docker_only"
        nargs = '?'
        constant = false
        default = false
        eval_arg = true
    end
    #! format: on
    parsed_args = parse_args(args, s)

    package_path = dirname(@__DIR__)

    configuration = build_configuration(;
        package_path = package_path,
        development_stage = parsed_args["development_stage"],
        version_suffix = parsed_args["version_suffix"],
    )

    memory_in_gb = if os == "linux"
        30
    else
        16
    end

    return start_ecs_task_and_watch(;
        configuration = configuration,
        os = parsed_args["os"],
        memory_in_gb = memory,
        overwrite = parsed_args["overwrite"],
    )
end

exit(main(ARGS))
