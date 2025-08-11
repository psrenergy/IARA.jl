using Statistics

cost_results = open("cost_results.json", "r") do f
    return IARA.SDDP.JSON.parse(f)
end

deficit_results = open("deficit_results.json", "r") do f
    return IARA.SDDP.JSON.parse(f)
end

total_cost_dict = Dict{String, Vector{Float64}}()

for (key, value) in cost_results
    file = split(key, "\",")[1]
    if !haskey(total_cost_dict, file)
        total_cost_dict[file] = Float64[]
    end
    if !isnothing(value)
        total_cost = value + deficit_results[key] * 2e6 # deficit cost in [$/GWh]
        push!(total_cost_dict[file], total_cost / 1e3)
    end
end

for (file, costs) in total_cost_dict
    println("----------------------------")
    println("File: $file")
    println("Average cost: $(mean(costs))")
    println("Standard deviation: $(std(costs))")
end