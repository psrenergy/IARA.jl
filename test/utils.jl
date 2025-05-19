#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

using Quiver

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

function compare_files(
    output_name::String,
    output_file::String,
    expected_output_file::String;
    test_only_subperiod_sum::Vector{String} = String[],
    test_only_first_subperiod::Vector{String} = String[],
)
    output_reader = Quiver.Reader{Quiver.csv}(output_file)
    expected_output_reader = Quiver.Reader{Quiver.csv}(expected_output_file)

    try
        @test output_reader.metadata == expected_output_reader.metadata
    catch
        Quiver.close!(output_reader)
        Quiver.close!(expected_output_reader)
        @test false
        return
    end

    try
        dimension_names = output_reader.metadata.dimensions
        dimension_size = output_reader.metadata.dimension_size

        # Compare the outputs
        if any(startswith.(output_name, test_only_subperiod_sum))
            if dimension_names == [:period, :scenario, :subperiod]
                for period in 1:dimension_size[1], scenario in 1:dimension_size[2]
                    sum_in_subperiods_calculated_output = 0.0
                    sum_in_subperiods_expected_output = 0.0
                    for subperiod in 1:dimension_size[3]
                        output_data = Quiver.goto!(output_reader; period, scenario, subperiod)
                        expected_output_data = Quiver.goto!(expected_output_reader; period, scenario, subperiod)
                        sum_in_subperiods_calculated_output += sum(output_data)
                        sum_in_subperiods_expected_output += sum(expected_output_data)
                    end
                    @test sum_in_subperiods_calculated_output ≈ sum_in_subperiods_expected_output atol = TEST_ATOL rtol =
                        1e-4
                end
            else
                @warn("Comparison not implementend. Could not compare the output $output_name")
            end
        elseif output_name in test_only_first_subperiod
            if dimension_names == [:period, :scenario, :subperiod]
                for period in 1:dimension_size[1], scenario in 1:dimension_size[2], subperiod in 1:1
                    output_data = Quiver.goto!(output_reader; period, scenario, subperiod)
                    expected_output_data = Quiver.goto!(expected_output_reader; period, scenario, subperiod)
                    @test output_data ≈ expected_output_data atol = TEST_ATOL rtol = TEST_RTOL
                end
            else
                @warn("Comparison not implementend. Could not compare the output $output_name")
            end
        else # compare every entry
            @test Quiver.compare_files(
                output_file,
                expected_output_file,
                Quiver.csv;
                atol = TEST_ATOL,
                rtol = TEST_RTOL,
            )
        end
    finally
        Quiver.close!(output_reader)
        Quiver.close!(expected_output_reader)
    end
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
