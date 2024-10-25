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

function get_list_of_expected_outputs(expected_outputs_folder::String, skipped_outputs::Vector{String})
    list_of_outputs = String[]
    for file in readdir(expected_outputs_folder)
        if endswith(file, ".csv")
            output_name = split(file, ".")[1]
            if output_name in skipped_outputs
                continue
            end
            push!(list_of_outputs, output_name)
        end
    end
    return list_of_outputs
end

function compare_outputs(
    case_path::String;
    test_only_subperiod_sum::Vector{String} = String[],
    test_only_first_subperiod::Vector{String} = String[],
    skipped_outputs::Vector{String} = ["load_marginal_cost", "hydro_opportunity_cost", "generation"],
)
    outputs_folder = joinpath(case_path, "outputs")
    expected_outputs_folder = joinpath(case_path, "expected_outputs")

    # For each file in the expected_outputs_folder, load the output and the expected outputs and compare them
    list_of_outputs = get_list_of_expected_outputs(expected_outputs_folder, skipped_outputs)

    println("")
    @info("Comparing the outputs $(join(list_of_outputs, ", "))")
    for output in list_of_outputs
        @info("Comparing the output $output")
        output_file = joinpath(outputs_folder, output)
        expected_output_file = joinpath(expected_outputs_folder, output)

        output_reader = Quiver.Reader{Quiver.csv}(output_file)
        expected_output_reader = Quiver.Reader{Quiver.csv}(expected_output_file)

        try
            @test output_reader.metadata == expected_output_reader.metadata
        catch
            Quiver.close!(output_reader)
            Quiver.close!(expected_output_reader)
            continue
        end

        try
            dimension_names = output_reader.metadata.dimensions
            dimension_size = output_reader.metadata.dimension_size

            # Compare the outputs
            if output in test_only_subperiod_sum
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
                        @test sum_in_subperiods_calculated_output ≈ sum_in_subperiods_expected_output atol = 1e-6 rtol =
                            1e-4
                    end
                else
                    @warn("Comparison not implementend. Could not compare the output $output")
                end
            elseif output in test_only_first_subperiod
                if dimension_names == [:period, :scenario, :subperiod]
                    for period in 1:dimension_size[1], scenario in 1:dimension_size[2], subperiod in 1:1
                        output_data = Quiver.goto!(output_reader; period, scenario, subperiod)
                        expected_output_data = Quiver.goto!(expected_output_reader; period, scenario, subperiod)
                        @test output_data ≈ expected_output_data atol = 1e-6 rtol = 1e-4
                    end
                else
                    @warn("Comparison not implementend. Could not compare the output $output")
                end
            else # compare every entry
                if dimension_names == [:period, :scenario, :subperiod]
                    for period in 1:dimension_size[1], scenario in 1:dimension_size[2], subperiod in 1:dimension_size[3]
                        output_data = Quiver.goto!(output_reader; period, scenario, subperiod)
                        expected_output_data = Quiver.goto!(expected_output_reader; period, scenario, subperiod)
                        @test output_data ≈ expected_output_data atol = 1e-6 rtol = 1e-4
                    end
                elseif dimension_names == [:period, :scenario, :subperiod, :bid_segment]
                    for period in 1:dimension_size[1], scenario in 1:dimension_size[2],
                        subperiod in 1:dimension_size[3],
                        bid_segment in 1:dimension_size[4]

                        output_data = Quiver.goto!(output_reader; period, scenario, subperiod, bid_segment)
                        expected_output_data =
                            Quiver.goto!(expected_output_reader; period, scenario, subperiod, bid_segment)
                        @test output_data ≈ expected_output_data atol = 1e-6 rtol = 1e-4
                    end
                else
                    @warn("Comparison not implementend. Could not compare the output $output")
                end
            end
        finally
            Quiver.close!(output_reader)
            Quiver.close!(expected_output_reader)
        end
    end
    return nothing
end

function update_outputs!(case_path::String)
    expected_output_path = joinpath(case_path, "expected_outputs")
    output_path = joinpath(case_path, "outputs")
    cp(output_path, expected_output_path; force = true)
    return nothing
end
