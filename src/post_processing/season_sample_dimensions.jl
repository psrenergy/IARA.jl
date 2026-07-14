#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

"""
    add_season_sample_dimensions(output_file; period_season_map_file, destination_file)

Read a cyclic-run output's `.qvr` binary and its `period_season_map`, and write a Quiver binary
file with `season` and `sample` added as dimensions right after `scenario`. Returns the path of
the written file.
"""
function add_season_sample_dimensions(
    output_file::String;
    period_season_map_file::String = joinpath(dirname(output_file), "period_season_map"),
    destination_file::String = first(splitext(output_file)) * "_with_season",
)
    output_base = first(splitext(output_file))
    if !isfile(output_base * ".qvr")
        error("Could not find a \"$output_base.qvr\" file to read.")
    end
    array_data, metadata = binary_file_to_array(output_base)
    @warn(
        "The binary format pre-allocates the full dense grid (the product of every dimension " *
        "size), which is inefficient for the sparse season/sample dimensions added.",
    )
    # Reshape into the same row-per-coordinate DataFrame shape the rest of this function expects
    dimension_names = metadata_dimension_names(metadata)
    dimension_sizes = metadata_dimension_sizes(metadata)
    labels = Quiver.Binary.get_labels(metadata)
    output = DataFrame()
    for (i, name) in enumerate(dimension_names)
        insertcols!(output, name => Int[])
    end
    for label in labels
        insertcols!(output, Symbol(label) => Float64[])
    end
    dims = first_position!(copy(dimension_sizes))
    for _ in 1:prod(dimension_sizes)
        next_dim!(dims, dimension_sizes)
        push!(output, [reverse(dims)...; array_data[:, reverse(dims)...]...])
    end

    @assert metadata_dimension_names(metadata)[1] == :period
    @assert metadata_dimension_names(metadata)[2] == :scenario

    map_df = select(
        CSV.read(first(splitext(period_season_map_file)) * ".csv", DataFrame),
        [:period, :scenario, :season, :sample],
    )
    transform!(map_df, :season => ByRow(Int) => :season, :sample => ByRow(Int) => :sample)

    result = leftjoin(output, map_df; on = [:period, :scenario])
    if any(ismissing, result.season)
        error("The period_season_map does not cover all (period, scenario) pairs in \"$output_file\".")
    end

    original_dims = string.(metadata_dimension_names(metadata))
    dimensions = vcat(original_dims[1:2], ["season", "sample"], original_dims[3:end])
    dimension_size = vcat(
        dimension_sizes[1:2],
        [maximum(result.season), maximum(result.sample)],
        dimension_sizes[3:end],
    )

    dimension_columns = Symbol.(dimensions)
    label_columns = Symbol.(labels)
    select!(result, vcat(dimension_columns, label_columns))
    sort!(result, dimension_columns)

    # Quiver cannot read a hole at the maximum dimension combination. Materialize the corner 
    # with a NaN row when it is missing, keeping the sorted order intact. 
    if any(i -> result[end, dimension_columns[i]] != dimension_size[i], eachindex(dimension_size))
        sentinel = Dict{Symbol, Any}(dimension_columns[i] => dimension_size[i] for i in eachindex(dimension_size))
        for column in label_columns
            sentinel[column] = NaN
        end
        push!(result, sentinel)
    end

    new_md = Quiver.Binary.Metadata(;
        initial_datetime = Quiver.Binary.get_initial_datetime(metadata),
        unit = Quiver.Binary.get_unit(metadata),
        labels = Quiver.Binary.get_labels(metadata),
        dimensions = dimensions,
        dimension_sizes = Int64.(dimension_size),
    )
    writer = Quiver.Binary.open_file(destination_file; mode = 'w', metadata = new_md)
    for row in eachrow(result)
        dimension_values = [row[column] for column in dimension_columns]
        data_values = Float64[row[column] for column in label_columns]
        write_kwargs = NamedTuple(dimension_columns[i] => dimension_values[i] for i in eachindex(dimension_columns))
        Quiver.Binary.write!(writer; data = data_values, write_kwargs...)
    end
    Quiver.Binary.close!(writer)

    return destination_file
end

"""
    add_season_sample_dimensions_to_dir(dir; period_season_map_file, destination_dir)

Process all Quiver output files in `dir` by calling `add_season_sample_dimensions` on each
TOML file found (excluding `period_season_map`).
"""
function add_season_sample_dimensions_to_dir(
    dir::String;
    period_season_map_file::String = joinpath(dir, "period_season_map"),
    destination_dir::String = dir * "_with_season_sample",
)
    mkpath(destination_dir)
    for file in readdir(dir; join = false)
        base, ext = splitext(file)
        if ext != ".toml" || base == "period_season_map"
            continue
        end
        full_base = joinpath(dir, base)
        if !isfile(full_base * ".csv") && !isfile(full_base * ".qvr")
            continue
        end
        add_season_sample_dimensions(
            full_base;
            period_season_map_file = period_season_map_file,
            destination_file = joinpath(destination_dir, base * "_with_season"),
        )
    end
    return nothing
end
