module TestInterfaceCalls

using Test
using IARA
using JSON

const PSRDatabaseSQLite = IARA.PSRDatabaseSQLite

function test_iara_interface_call()
    # Build an example case
    case_path = joinpath(pwd(), "test_iara_interface_call")
    if isdir(case_path)
        rm(case_path; force = true, recursive = true)
    end
    IARA.ExampleCases.build_example_case(case_path, "boto_base_01")

    case_outputs_path = joinpath(case_path, "outputs")
    # Run the interface call
    IARA.InterfaceCalls.interface_call(case_path)

    # json with case information
    json_file = joinpath(case_outputs_path, "iara_elements.json")
    @test isfile(json_file)
    inflow_file = joinpath(case_outputs_path, "inflows_all.html")
    @test isfile(inflow_file)
    return nothing
end

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$name", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

TestInterfaceCalls.runtests()

end #module 
