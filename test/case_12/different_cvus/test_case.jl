module TestCase12DifferentCVUs

using Test
using IARA

const PATH = @__DIR__

db = nothing
try
    include("../base_case/build_case.jl")
    include("./modify_case.jl")
finally
    if db !== nothing
        IARA.close_study!(db)
    end
end

IARA.single_period_market_clearing(
    PATH;
    plot_outputs = false,
    delete_output_folder_before_execution = true,
    period = 1,
    plot_ui_outputs = true,
)

if Main.UPDATE_RESULTS
    Main.update_outputs!(PATH)
else
    Main.compare_outputs(PATH)
end

end
