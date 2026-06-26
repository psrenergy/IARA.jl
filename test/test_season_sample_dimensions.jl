#############################################################################
#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

module TestSeasonSampleDimensions

using Test
using IARA
import Quiver

const EXPECTED_DIR = joinpath(@__DIR__, "case_01", "cyclic_graph_case", "expected_outputs")

function test_add_season_sample_dimensions()
    # A cyclic-run output (indexed by period, scenario, subperiod) and its period_season_map.
    base = IARA.add_season_sample_dimensions(
        joinpath(EXPECTED_DIR, "hydro_generation");
        destination_file = joinpath(mktempdir(), "hydro_generation_with_season"),
    )

    # The result is a valid Quiver file (.csv + .toml) with season and sample added as dimensions.
    # Note: this file is SPARSE — it stores only the real (period, scenario, ...) rows tagged with
    # their season/sample. The absent (season, sample) combinations are not written and read back as
    # NaN. (Quiver operations such as apply_expression, however, produce a dense output.)
    @test isfile(base * ".csv")
    @test isfile(base * ".toml")
    _, metadata = IARA.read_timeseries_file(base * ".csv")
    @test metadata.dimensions == [:period, :scenario, :season, :sample, :subperiod]
    return nothing
end

function test_aggregate_with_quiver_apply_expression()
    base = IARA.add_season_sample_dimensions(
        joinpath(EXPECTED_DIR, "hydro_generation");
        destination_file = joinpath(mktempdir(), "hydro_generation_with_season"),
    )

    # The file works with Quiver's apply_expression: sum over subperiods (season/sample are kept),
    # and the NaN sentinel row stays an inert hole instead of leaking into the real cells.
    aggregated = joinpath(mktempdir(), "hydro_generation_aggregated")
    Quiver.apply_expression_over_dimension(aggregated, base, sum, :subperiod, Quiver.csv; digits = 6)

    data, metadata = IARA.read_timeseries_file(aggregated * ".csv")
    @test metadata.dimensions == [:period, :scenario, :season, :sample]
    # data layout = [label, sample, season, scenario, period]; (period 1, scenario 1) -> season 1, sample 2.
    @test data[1, 2, 1, 1, 1] ≈ 0.12   # 0.06 + 0.06 over the two subperiods
    return nothing
end

function test_add_season_sample_dimensions_quiv()
    # Build a .quiv copy of the CSV source (plus its period_season_map) in a temp dir.
    dir = mktempdir()
    Quiver.convert(
        joinpath(EXPECTED_DIR, "hydro_generation"),
        Quiver.csv,
        Quiver.binary;
        destination_directory = dir,
        filename = "hydro_generation",
    )
    for ext in (".csv", ".toml")
        cp(joinpath(EXPECTED_DIR, "period_season_map" * ext), joinpath(dir, "period_season_map" * ext))
    end

    base = IARA.add_season_sample_dimensions(joinpath(dir, "hydro_generation"))
    @test isfile(base * ".quiv")
    _, metadata = IARA.read_timeseries_file(base * ".quiv")
    @test metadata.dimensions == [:period, :scenario, :season, :sample, :subperiod]
    return nothing
end

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$name", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

TestSeasonSampleDimensions.runtests()

end #module
