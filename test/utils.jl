#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

using CSV
using DataFrames
using TOML

const TEST_ATOL = 1e-6
const TEST_RTOL = 1e-2

function get_list_of_expected_outputs(expected_outputs_folder::String, skipped_outputs::Vector{String})
    list_of_outputs = Dict{String, String}()
    output_suffixes = [
        "",
        "_ex_ante_physical",
        "_ex_ante_commercial",
        "_ex_post_physical",
        "_ex_post_commercial",
        "_commercial",
        "_physical",
        "_ex_ante",
        "_ex_post",
    ]
    skipped_outputs = [output * suffix for output in skipped_outputs, suffix in output_suffixes]
    for (root, dirs, files) in walkdir(expected_outputs_folder)
        for file in files
            filename = joinpath(root, file)
            if endswith(filename, ".csv")
                file_without_extension = join(split(filename, ".")[1:end-1], ".")
                output_name = basename(file_without_extension)
                if output_name in skipped_outputs
                    continue
                end
                list_of_outputs[output_name] = file_without_extension
            end
        end
    end
    return list_of_outputs
end

function compare_outputs(
    case_path::String;
    test_only_subperiod_sum::Vector{String} = String[],
    test_only_first_subperiod::Vector{String} = String[],
    skipped_outputs::Vector{String} = String[],
)
    outputs_folder = joinpath(case_path, "outputs")
    expected_outputs_folder = joinpath(case_path, "expected_outputs")

    default_skipped_outputs = [
        "load_marginal_cost",
        "hydro_opportunity_cost",
        "generation",
        "bidding_group_revenue",
        "bidding_group_total_revenue",
    ]
    skipped_outputs = union(skipped_outputs, default_skipped_outputs)

    # For each file in the expected_outputs_folder, load the output and the expected outputs and compare them
    list_of_outputs = get_list_of_expected_outputs(expected_outputs_folder, skipped_outputs)

    println("")
    @info("Comparing the outputs $(join(collect(keys(list_of_outputs)), ", "))")
    for (output_name, output_path) in list_of_outputs
        @info("Comparing the output $output_name")
        expected_output_file = output_path
        output_file = replace(output_path, "expected_outputs" => "outputs")
        compare_files(
            output_name,
            output_file,
            expected_output_file;
            test_only_subperiod_sum = test_only_subperiod_sum,
            test_only_first_subperiod = test_only_first_subperiod,
        )
    end
    return nothing
end

"""
    metadata_matches(md1::Dict{String, Any}, md2::Dict{String, Any})

Compare the dimensions, dimension sizes, labels and unit of two parsed Quiver `.toml` files.
"""
function metadata_matches(md1::Dict{String, Any}, md2::Dict{String, Any})
    return md1["dimensions"] == md2["dimensions"] &&
           md1["dimension_sizes"] == md2["dimension_sizes"] &&
           md1["labels"] == md2["labels"] &&
           md1["unit"] == md2["unit"]
end

"""
    compare_dataframes(output_df, expected_df, dimension_names, label_names; atol, rtol)

Compare every row of two CSV-derived `DataFrame`s positionally — both files are written by
iterating dimensions in the same fixed order, so row `i` in one corresponds to row `i` in the
other. Dimension columns must match exactly; label columns are compared with `isapprox`,
treating `missing` specially: a `missing` in one file must also be `missing` in the other at
the same row (checked exactly, since `missing == missing` is `missing`, not `true`), and
non-missing positions are compared numerically at `atol`/`rtol`.
"""
function compare_dataframes(
    output_df::DataFrame,
    expected_df::DataFrame,
    dimension_names::Vector{Symbol},
    label_names::Vector{Symbol};
    atol,
    rtol,
)
    nrow(output_df) != nrow(expected_df) && return false
    for row_index in 1:nrow(output_df)
        for dimension in dimension_names
            output_df[row_index, dimension] != expected_df[row_index, dimension] && return false
        end
        for label in label_names
            output_value = output_df[row_index, label]
            expected_value = expected_df[row_index, label]
            ismissing(output_value) != ismissing(expected_value) && return false
            if !ismissing(output_value) && !isapprox(Float64(output_value), Float64(expected_value); atol, rtol)
                return false
            end
        end
    end
    return true
end

function compare_files(
    output_name::String,
    output_file::String,
    expected_output_file::String;
    test_only_subperiod_sum::Vector{String} = String[],
    test_only_first_subperiod::Vector{String} = String[],
)
    output_md = TOML.parsefile(output_file * ".toml")
    expected_md = TOML.parsefile(expected_output_file * ".toml")

    metadata_ok = metadata_matches(output_md, expected_md)
    @test metadata_ok
    if !metadata_ok
        return
    end

    dimension_names = Symbol.(expected_md["dimensions"])
    dimension_size = Int.(expected_md["dimension_sizes"])
    label_names = Symbol.(expected_md["labels"])

    output_df = CSV.read(output_file * ".csv", DataFrame; missingstring = "null")
    expected_df = CSV.read(expected_output_file * ".csv", DataFrame; missingstring = "null")

    if any(startswith.(output_name, test_only_subperiod_sum))
        if dimension_names == [:period, :scenario, :subperiod]
            for period in 1:dimension_size[1], scenario in 1:dimension_size[2]
                output_rows = filter(row -> row.period == period && row.scenario == scenario, output_df)
                expected_rows = filter(row -> row.period == period && row.scenario == scenario, expected_df)
                sum_in_subperiods_calculated_output = sum(coalesce.(Matrix(output_rows[:, label_names]), NaN))
                sum_in_subperiods_expected_output = sum(coalesce.(Matrix(expected_rows[:, label_names]), NaN))
                @test sum_in_subperiods_calculated_output ≈ sum_in_subperiods_expected_output atol = TEST_ATOL rtol =
                    1e-4
            end
        else
            @warn("Comparison not implemented. Could not compare the output $output_name")
        end
    elseif output_name in test_only_first_subperiod
        if dimension_names == [:period, :scenario, :subperiod]
            for period in 1:dimension_size[1], scenario in 1:dimension_size[2]
                output_row =
                    filter(row -> row.period == period && row.scenario == scenario && row.subperiod == 1, output_df)
                expected_row = filter(
                    row -> row.period == period && row.scenario == scenario && row.subperiod == 1,
                    expected_df,
                )
                output_data = collect(output_row[1, label_names])
                expected_data = collect(expected_row[1, label_names])
                nan_mask = ismissing.(expected_data)
                @test ismissing.(output_data) == nan_mask
                valid = .!nan_mask
                if any(valid)
                    @test Float64.(output_data[valid]) ≈ Float64.(expected_data[valid]) atol = TEST_ATOL rtol =
                        TEST_RTOL
                end
            end
        else
            @warn("Comparison not implemented. Could not compare the output $output_name")
        end
    else # compare every entry
        @test compare_dataframes(
            output_df,
            expected_df,
            dimension_names,
            label_names;
            atol = TEST_ATOL,
            rtol = TEST_RTOL,
        )
    end
    return nothing
end

function update_outputs!(case_path::String)
    expected_output_path = joinpath(case_path, "expected_outputs")
    output_path = joinpath(case_path, "outputs")
    cp(output_path, expected_output_path; force = true)
    return nothing
end

function copy_files(origin_path::String, destination_path::String, filter_function::Function)
    for file in readdir(origin_path)
        if filter_function(file)
            cp(joinpath(origin_path, file), joinpath(destination_path, file); force = true)
        end
    end
    return nothing
end

function send_files(origin_path::String, destination_path::String)
    if !isdir(destination_path)
        mkdir(destination_path)
    end
    for file in readdir(origin_path)
        if isfile(joinpath(origin_path, file))
            Base.Filesystem.sendfile(joinpath(origin_path, file), joinpath(destination_path, file))
        end
    end
    return nothing
end
