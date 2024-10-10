#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

using Test
using Random
using IARA

Random.seed!(1234)
include("utils.jl")

const UPDATE_RESULTS = "update_test_results" in ARGS
const RUN_BIG_TESTS = "run_big_tests" in ARGS

if UPDATE_RESULTS
    @info "Updating test results"
else
    @info "Testing results"
end

function test_modules(dir::AbstractString)
    result = Dict{String, Vector{String}}()
    for (root, dirs, files) in walkdir(dir)
        for file in joinpath.(root, filter(f -> occursin(r"test_(.)+\.jl", f), files))
            main_case = splitpath(file)[end-2]
            if !haskey(result, main_case)
                result[main_case] = String[]
            end
            push!(result[main_case], file)
        end
    end
    return result
end

# Fill the dict following the pattern below
reduced_test_list = Dict(
# "case_01" => [
#     "case_01/hydro_minimum_outflow_case/test_hydro_minimum_outflow_case.jl",
# "case_01/markup_bids_case/test_markup_bids_case.jl",
#     "case_01/reserve_case/test_reserve_case.jl",
# ],
# "case_02" => [
#     "case_02/reserve_case/test_reserve_case.jl",
# ],
# "case_04" => [
#     "case_04/virtual_plants_case/test_virtual_plants_case.jl",
#     "case_04/aggregated_strategic_bid_case/test_aggregated_strategic_bid_case.jl",
#     "case_04/base_case/test_base_case.jl",
#     "case_04/ex_post_case/test_ex_post_case.jl",
# ],
# "case_06" => [
#     "case_06/base_case/test_base_case.jl",
#     "case_06/multihour_simple/test_multihour_case.jl",
#     "case_06/multihour_complex_min_activation/test_multihour_complex1.jl",
#     "case_06/multihour_complex_precedence/test_multihour_complex2.jl",
#     "case_06/multihour_complex_complementary_group/test_multihour_complex3.jl",
# ],
)

test_list = isempty(reduced_test_list) ? test_modules(@__DIR__) : reduced_test_list

@testset "Tests" begin
    for (main_case, files) in test_list
        @testset "$main_case" begin
            for file in files
                @testset "$(basename(dirname(file)))" begin
                    include(file)
                end
            end
        end
    end
end
