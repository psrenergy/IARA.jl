using Test
using IARA

const PATH = @__DIR__

db = nothing
try
    include("build_case.jl")
finally
    if db !== nothing
        IARA.close_study!(db)
    end
end