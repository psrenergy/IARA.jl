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
#     "case_01/ac_line_case/test_case.jl",
#     "case_01/ac_line_foo_case/test_case.jl",
#     "case_01/ac_line_with_dc_flag_case/test_case.jl",
#     "case_01/aggregate_hydro_balance/test_case.jl",
#     "case_01/base_case/test_case.jl",
#     "case_01/base_case_simulation/test_case.jl",
#     "case_01/battery_case/test_case.jl",
#     "case_01/big_simulation_case/test_case.jl",
#     "case_01/cyclic_graph_case/test_case.jl",
#     "case_01/elastic_demand_case/test_case.jl",
#     "case_01/gnd_modifications_case/test_case.jl",
#     "case_01/hourly_data_case/test_case.jl",
#     "case_01/hydro_cascading_case/test_case.jl",
#     "case_01/hydro_cascading_case_run_of_river/test_case.jl",
#     "case_01/hydro_cascading_case_run_of_river3/test_case.jl",
#     "case_01/hydro_cascading_case_run_of_river_existing/test_case.jl",
#     "case_01/hydro_commitment_case/test_case.jl",
#     "case_01/hydro_minimum_outflow_case/test_case.jl",
#     "case_01/price_takers_case/test_case.jl",
#     "case_01/renewable_curtailment_case/test_case.jl",
#     "case_01/renewable_om_cost_case/test_case.jl",
#     "case_01/repeating_nodes_case/test_case.jl",
#     "case_01/thermal_commitment_case/test_case.jl",
#     "case_01/thermal_ramp_case/test_case.jl",
# ],
# "case_02" => [
#     "case_02/base_case/test_case.jl",
#     "case_02/connected_subperiods_case/test_case.jl",
#     "case_02/variable_subperiod_duration_case/test_case.jl",
# ],
# "case_03" => [
#     "case_03/base_case/test_case.jl",,
# ],
# "case_04" => [
#     "case_04/aggregated_strategic_bid_case/test_case.jl",
#     "case_04/base_case/test_case.jl",
#     "case_04/ex_post_case/test_case.jl",
#     "case_04/skip_case/test_case.jl",
#     "case_04/strategic_bid_case/test_case.jl",
#     "case_04/virtual_plants_case/test_case.jl",
# ],
# "case_05" => [
#     "case_05/base_case/test_case.jl",
#     "case_05/incremental_inflow_case/test_case.jl",
# ],
# "case_06" => [
#     "case_06/base_case/test_case.jl",
#     "case_06/profile_complex_complementary_group/test_case.jl",
#     "case_06/profile_complex_min_activation/test_case.jl",
#     "case_06/profile_complex_precedence/test_case.jl",
#     "case_06/profile_simple/test_case.jl",
# ],
# "case_07" => [
#     "case_07/base_case/test_case.jl",
#     "case_07/skip_case/test_case.jl",
#     "case_07/virtual_reservoir_and_thermal/test_case.jl",
# ],
# "case_08" => [
#     "case_08/base_case/test_case.jl",
#     "case_08/physical_virtual_correspondence_by_volume_case/test_case.jl",
# ],
# "case_09" => [
#     "case_09/base_case/test_case.jl",
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
