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
        constant = "Stable release"
        default = "Stable release"
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

    os = parsed_args["os"]

    if !parsed_args["docker_only"]
        memory_in_gb = if os == "linux"
            30
        else
            16
        end

        start_ecs_task_and_watch(;
            configuration = configuration,
            os = os,
            memory_in_gb = memory_in_gb,
            overwrite = parsed_args["overwrite"],
        )
    end

    CD.deploy_to_ghcr(;
        configuration = configuration,
        dockerfile = joinpath(package_path, "docker", "Dockerfile"),
        build_context = joinpath(package_path, "docker"),
        inject_url_build_arg = "IARA_URL",
    )
    return 0
end

exit(main(ARGS))
