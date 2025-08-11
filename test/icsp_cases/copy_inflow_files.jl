result = Dict{String, Vector{String}}()
for (root, dirs, files) in walkdir(raw"D:\Repositorios\IARA.jl\test\icsp_cases")
    for file in joinpath.(root, filter(f -> occursin("inflow.csv", f), files))
        try
            seed = splitpath(file)[end-1]
            @show seed
            parse(Int, seed)
        catch
            continue
        end
        main_case = splitpath(file)[end-2]
        if !haskey(result, main_case)
            result[main_case] = String[]
        end
        push!(result[main_case], file)
    end
end
for (case, files) in result
    println("Case: $case")
    for file in files
        println("  - $file")
    end
end

mkdir(raw"D:\Repositorios\IARA.jl\test\icsp_cases\inflow_files")

for (case, files) in result
    mkdir("D:/Repositorios/IARA.jl/test/icsp_cases/inflow_files/$case")
    println("Case: $case")
    for file in files
        filename = (split(splitpath(file)[end], ".csv")[1])
        new_filename = "$(filename)_$(splitpath(file)[end-1]).csv"
        cp(file, "D:/Repositorios/IARA.jl/test/icsp_cases/inflow_files/$case/$new_filename")
        println("  - $file")
    end
end