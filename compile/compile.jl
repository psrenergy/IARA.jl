import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using ArgParse
using PSRContinuousDeployment

function main(args::Vector{String})
    s = ArgParseSettings()
    #! format: off
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
    assets_path = joinpath(@__DIR__, "assets")
    database_path = joinpath(package_path, "database")

    configuration = build_configuration(;
        package_path = package_path,
        development_stage = parsed_args["development_stage"],
        version_suffix = parsed_args["version_suffix"],
    )

    build_docs(configuration)

    PSRContinuousDeployment.compile(
        configuration;
        executables = [
            "IARA" => "julia_main",
            "IARA_UI" => "InterfaceCalls.julia_main",
        ],
        additional_files_path = [
            database_path,
        ],
        windows_additional_files_path = [
            joinpath(assets_path, "IARA.bat"),
        ],
        linux_additional_files_path = [
            joinpath(assets_path, "IARA.sh"),
            joinpath(assets_path, "IARA_interface_call.sh"),
        ],
    )

    return 0
end

main(ARGS)
