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
    os = parsed_args["os"]
    docker_only = parsed_args["docker_only"]

    package_path = dirname(@__DIR__)

    configuration = build_configuration(;
        package_path = package_path,
        development_stage = parsed_args["development_stage"],
        version_suffix = parsed_args["version_suffix"],
    )

    if os == "windows"
        CD.trigger_hub_async_workflow(configuration)
    end

    exit_code = 0
    if !docker_only
        memory_in_gb = if os == "linux"
            30
        else
            16
        end

        exit_code = start_ecs_task_and_watch(;
            configuration = configuration,
            os = os,
            memory_in_gb = memory_in_gb,
            overwrite = parsed_args["overwrite"],
        )
    end

    if os == "linux" && exit_code == 0
        CD.deploy_to_ghcr(;
            configuration = configuration,
            dockerfile = joinpath(package_path, "docker", "Dockerfile"),
            build_context = joinpath(package_path, "docker"),
            url_build_arg = "IARA_URL",
        )
    end

    return exit_code
end

exit(main(ARGS))
