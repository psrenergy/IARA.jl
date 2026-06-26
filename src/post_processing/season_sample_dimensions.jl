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

Read a cyclic-run output and its `period_season_map`, and write a Quiver file with `season` and
`sample` added as dimensions right after `scenario`. Returns the path of the written file.
"""
function add_season_sample_dimensions(
    output_file::String;
    period_season_map_file::String = joinpath(dirname(output_file), "period_season_map"),
    destination_file::String = first(splitext(output_file)) * "_with_season",
)
    output_base = first(splitext(output_file))
    output = CSV.read(output_base * ".csv", DataFrame)
    metadata = Quiver.from_toml(output_base * ".toml")

    @assert metadata.dimensions[1] == :period
    @assert metadata.dimensions[2] == :scenario

    map_df = select(
        CSV.read(first(splitext(period_season_map_file)) * ".csv", DataFrame),
        [:period, :scenario, :season, :sample],
    )
    transform!(map_df, :season => ByRow(Int) => :season, :sample => ByRow(Int) => :sample)

    result = leftjoin(output, map_df; on = [:period, :scenario])
    if any(ismissing, result.season)
        error("The period_season_map does not cover all (period, scenario) pairs in \"$output_file\".")
    end

    original_dims = string.(metadata.dimensions)
    dimensions = vcat(original_dims[1:2], ["season", "sample"], original_dims[3:end])
    dimension_size = vcat(
        metadata.dimension_size[1:2],
        [maximum(result.season), maximum(result.sample)],
        metadata.dimension_size[3:end],
    )

    dimension_columns = Symbol.(dimensions)
    label_columns = Symbol.(metadata.labels)
    select!(result, vcat(dimension_columns, label_columns))
    sort!(result, dimension_columns)

    # The Quiver CSV reader errors ("No more data to read") instead of returning NaN past the last
    # physical row, so a hole at the maximum dimension combination breaks reads. Append a NaN row
    # there when it is missing (at most one extra row), keeping the sorted order intact.
    if any(i -> result[end, dimension_columns[i]] != dimension_size[i], eachindex(dimension_size))
        sentinel = Dict{Symbol, Any}(dimension_columns[i] => dimension_size[i] for i in eachindex(dimension_size))
        for column in label_columns
            sentinel[column] = NaN
        end
        push!(result, sentinel)
    end

    writer = Quiver.Writer{Quiver.csv}(
        destination_file;
        dimensions = dimensions,
        labels = metadata.labels,
        time_dimension = string(metadata.time_dimension),
        dimension_size = dimension_size,
        initial_date = metadata.initial_date,
        unit = metadata.unit,
        frequency = metadata.frequency,
    )
    for row in eachrow(result)
        dimension_values = [row[column] for column in dimension_columns]
        data_values = Float64[row[column] for column in label_columns]
        Quiver.write!(writer, data_values, dimension_values...)
    end
    Quiver.close!(writer)

    return destination_file
end
