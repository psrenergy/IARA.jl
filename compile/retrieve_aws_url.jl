import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using ArgParse
using PSRContinuousDeployment


function main(args::Vector{String})
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
    end
    #! format: on
    parsed_args = parse_args(args, s)


    package_path = dirname(@__DIR__)
    configuration = build_configuration(;
        package_path = package_path,
        development_stage = parsed_args["development_stage"],
        version_suffix = parsed_args["version_suffix"],
    )

    aws_zip_url = PSRContinuousDeployment.find_aws_linux_zip(configuration)

    println(aws_zip_url)

    return aws_zip_url
end

main(ARGS)
