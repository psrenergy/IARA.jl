base_cases = [
    "case_12_30_1/build_case.jl",
    # "case_2_180_1/build_case.jl",
]

seeds = [1, 2, 3, 4, 5, 6, 1234]

cost_results = Dict()
deficit_results = Dict()

# Run base
for seed in seeds
    for file in base_cases
        global PATH = joinpath(@__DIR__, dirname(file))
        println("Building $PATH - $seed...")
        Random.seed!(seed)
        try
            include(file)
        finally
            if db !== nothing
                IARA.close_study!(db)
            end
        end
        println("Running $PATH - $seed...")
        try
            IARA.train_min_cost(PATH; delete_output_folder_before_execution = true, plot_outputs = false, output_path = "$seed")
            println("Post-processing outputs $PATH - $seed...")
            output_dir = joinpath(PATH, "$seed")
            data, metadata = IARA.read_timeseries_file(joinpath(output_dir, "thermal_om_costs.csv"))
            cost_results[(file, seed)] = sum(data)
            data, metadata = IARA.read_timeseries_file(joinpath(output_dir, "deficit.csv"))
            deficit_results[(file, seed)] = sum(data)
        catch e
            println(e)
            println("Skipping results $PATH - $seed...")
            cost_results[(file, seed)] = NaN
            deficit_results[(file, seed)] = NaN
        end
    end
end

modified_cases = Dict(
    # "case_12_6_5/modify_case.jl" => "case_12_30_1/build_case.jl",
    # "case_12_1_30/modify_case.jl" => "case_12_30_1/build_case.jl",

    # "case_2_12_15/modify_case.jl" => "case_2_180_1/build_case.jl",
    # "case_2_1_180/modify_case.jl" => "case_2_180_1/build_case.jl",
)

for seed in seeds
    for (file, base_case_file) in modified_cases
        global PATH = joinpath(@__DIR__, dirname(file))
        println("Building $PATH - $seed...")
        Random.seed!(seed)
        try
            include(base_case_file)
            include(file)
        finally
            if db !== nothing
                IARA.close_study!(db)
            end
        end
        println("Running $PATH - $seed...")
        try
            IARA.train_min_cost(PATH; delete_output_folder_before_execution = true, plot_outputs = false, output_path = "$seed")
            println("Post-processing outputs $PATH - $seed...")
            output_dir = joinpath(PATH, "$seed")
            data, metadata = IARA.read_timeseries_file(joinpath(output_dir, "thermal_om_costs.csv"))
            cost_results[(file, seed)] = sum(data)
            data, metadata = IARA.read_timeseries_file(joinpath(output_dir, "deficit.csv"))
            deficit_results[(file, seed)] = sum(data)
        catch e
            println(e)
            println("Skipping results $PATH - $seed...")
            cost_results[(file, seed)] = NaN
            deficit_results[(file, seed)] = NaN
        end
    end
end

println(cost_results)
println("------------------------")
println(deficit_results)

open("cost_results.json", "w") do f
    return IARA.SDDP.JSON.print(f, cost_results)
end

open("deficit_results.json", "w") do f
    return IARA.SDDP.JSON.print(f, deficit_results)
end