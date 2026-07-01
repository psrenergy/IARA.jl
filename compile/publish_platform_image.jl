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

const PERSONAL_ACCESS_TOKEN = ENV["PERSONAL_ACCESS_TOKEN"]

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

    CD.initialize_aws()

    CD.deploy_to_ghcr(;
        configuration = configuration,
        dockerfile = joinpath(package_path, "docker", "Dockerfile"),
        build_context = joinpath(package_path, "docker"),
        image_name = "iara",
        tags = ["latest"],
        inject_url_build_arg = "IARA_URL",
        github_actor = "psrenergy",
        github_token = PERSONAL_ACCESS_TOKEN,
    )

    return 0
end

exit(main(ARGS))
