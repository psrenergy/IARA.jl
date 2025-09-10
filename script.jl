test_path = joinpath(@__DIR__, "test")
for i in 1:21
    number_string = string(i)
    if length(number_string) == 1
        number_string = "0" * number_string
    end
    outer_test_folder = joinpath(test_path, "case_" * number_string)
    for test_name in readdir(outer_test_folder)
        folder = joinpath(outer_test_folder, test_name, "expected_outputs")
        if !isdir(folder)
            println("$folder does not exist")
            continue
        end
        files = readdir(folder)
        for filename in files
            if startswith(filename, "hydro_minimum_outflow_violation_cost_expression")
                new_name = replace(filename, "hydro_minimum_outflow_violation_cost_expression" => "hydro_minimum_outflow_violation_cost")
                old_path = joinpath(folder, filename)
                new_path = joinpath(folder, new_name)
                mv(old_path, new_path)
            end
        end
    end
end