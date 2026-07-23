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
    read_season_sample_map(period_season_map_file::String, num_periods::Int, num_scenarios::Int)

Read `period_season_map_file` and return a `Dict` mapping each `(period, scenario)` pair, 
to its `(season, sample)` pair. Errors if the file does not cover that range.
"""
function read_season_sample_map(period_season_map_file::String, num_periods::Int, num_scenarios::Int)
    period_season_map_array, period_season_map_metadata =
        binary_file_to_array(first(splitext(period_season_map_file)))
    period_season_map_labels = Quiver.Binary.get_labels(period_season_map_metadata)
    season_label_idx = findfirst(==("season"), period_season_map_labels)
    sample_label_idx = findfirst(==("sample"), period_season_map_labels)
    map_num_periods, map_num_scenarios = metadata_dimension_sizes(period_season_map_metadata)
    if map_num_periods < num_periods || map_num_scenarios < num_scenarios
        error("The period_season_map in \"$period_season_map_file\" does not cover all (period, scenario) pairs.")
    end
    season_sample_by_period_scenario = Dict{Tuple{Int, Int}, Tuple{Int, Int}}()
    for scenario in 1:num_scenarios, period in 1:num_periods
        season_sample_by_period_scenario[(period, scenario)] = (
            Int(period_season_map_array[season_label_idx, scenario, period]),
            Int(period_season_map_array[sample_label_idx, scenario, period]),
        )
    end
    return season_sample_by_period_scenario
end

"""
    add_season_sample_dimensions(output_file; period_season_map_file, destination_file)

Read a cyclic-run output's `.qvr` binary and its `period_season_map`, and write a Quiver binary
file with `season` and `sample` added as dimensions right after `scenario`. Also writes a matching
`.csv`, with unused `(season, sample)` combinations removed. Returns the path of the written file.
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

    # TODO: Binary format pre-allocates the full dense grid (product of every dimension size),
    # which is inneficient for this. Worth checking in detail how it works on Quiver now.

    dimension_names = metadata_dimension_names(metadata)
    dimension_sizes = metadata_dimension_sizes(metadata)
    labels = String.(Quiver.Binary.get_labels(metadata))

    @assert dimension_names[1] == :period
    @assert dimension_names[2] == :scenario

    season_sample_by_period_scenario =
        read_season_sample_map(period_season_map_file, dimension_sizes[1], dimension_sizes[2])

    original_dims = string.(dimension_names)
    dimensions = vcat(original_dims[1:2], ["season", "sample"], original_dims[3:end])
    dimension_symbols = Symbol.(dimensions)
    max_season = maximum(first(v) for v in values(season_sample_by_period_scenario))
    max_sample = maximum(last(v) for v in values(season_sample_by_period_scenario))
    dimension_size = vcat(dimension_sizes[1:2], [max_season, max_sample], dimension_sizes[3:end])

    new_metadata = Quiver.Binary.Metadata(;
        initial_datetime = Quiver.Binary.get_initial_datetime(metadata),
        unit = Quiver.Binary.get_unit(metadata),
        labels = labels,
        dimensions = dimensions,
        dimension_sizes = dimension_size,
    )
    writer = Quiver.Binary.open_file(destination_file; mode = 'w', metadata = new_metadata)

    dims = first_position!(copy(dimension_sizes))
    names_tuple = Tuple(dimension_symbols)
    for _ in 1:prod(dimension_sizes)
        next_dim!(dims, dimension_sizes)
        season, sample = season_sample_by_period_scenario[(dims[1], dims[2])]
        new_dim_values = vcat(dims[1:2], [season, sample], dims[3:end])
        data_values = array_data[:, reverse(dims)...]
        write_kwargs = NamedTuple{names_tuple}(Tuple(new_dim_values))
        Quiver.Binary.write!(writer; data = data_values, write_kwargs...)
    end
    finalize_output!(writer)

    # The binary format pre-allocates the full dense grid, so every (season, sample) combination
    # gets a row even though only one is ever real per (period, scenario). Those unwritten cells
    # are read back as "null" in every label column; drop them here.
    csv_path = destination_file * ".csv"
    result_df = CSV.read(csv_path, DataFrame; missingstring = "null")
    label_columns = Symbol.(labels)
    filter!(row -> !all(ismissing, row[label_columns]), result_df)
    CSV.write(csv_path, result_df; missingstring = "null")

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
        if !isfile(full_base * ".qvr")
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
