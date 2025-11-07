using Test
using IARA

const PATH = @__DIR__

# if Main.RUN_BIG_TESTS
    db = nothing
    try
        include("build_case.jl")
    finally
        if db !== nothing
            IARA.close_study!(db)
        end
    end

    IARA.market_clearing(PATH; plot_outputs = false, delete_output_folder_before_execution = true)
# end