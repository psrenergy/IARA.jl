module TestCase07VirtualReservoirThermalPlant

using Test
using IARA

const PATH = @__DIR__

include("../base_case/build_base_case.jl")
include("build_virtual_reservoir_thermal_plant_case.jl")

IARA.main([PATH, "--write-lp"])

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH)
end

end
