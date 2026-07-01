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
    end
    #! format: on
    parsed_args = parse_args(args, s)

    package_path = dirname(@__DIR__)

    configuration = build_configuration(;
        package_path = package_path,
        development_stage = parsed_args["development_stage"],
        version_suffix = parsed_args["version_suffix"],
    )

    # `deploy_to_ghcr` logs in to ghcr.io, builds `docker/Dockerfile` and pushes it. It resolves
    # VERSION and COMMIT_HASH from the configuration/git tree on its own, and injects the AWS linux
    # zip URL as the IARA_URL build arg (replacing the old retrieve_deploy_data step).
    return CD.deploy_to_ghcr(;
        configuration = configuration,
        dockerfile = joinpath(package_path, "docker", "Dockerfile"),
        build_context = joinpath(package_path, "docker"),
        inject_url_build_arg = "IARA_URL",
    )
end

main(ARGS)
