#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

module IARA

using ArgParse
using JuMP
using HiGHS
using PSRClassesInterface
using DataFrames
using CSV
using SDDP
using Serialization
using Quiver
using Dates
using PSRBridge
using PlotlyLight
using EnumX
using ParametricOptInterface
using PAR
using OrderedCollections

using Libdl
using LinearAlgebra
using Random
using Statistics

const PSRI = PSRClassesInterface
const PSRDatabaseSQLite = PSRI.PSRDatabaseSQLite
const DatabaseSQLite = PSRI.PSRDatabaseSQLite.DatabaseSQLite
const POI = ParametricOptInterface

function initialize()
    set_plot_defaults()
    return nothing
end

include("version.jl")

include("enumx.jl")
include("run_time_options.jl")
include("revenue_convex_hull.jl")

include("collections/abstract_collection.jl")
include("collections/asset_owner.jl")
include("collections/battery.jl")
include("collections/bidding_group.jl")
include("collections/branch.jl")
include("collections/bus.jl")
include("collections/configurations.jl")
include("collections/dc_line.jl")
include("collections/demand.jl")
include("collections/gauging_station.jl")
include("collections/hydro_plant.jl")
include("collections/renewable_plant.jl")
include("collections/reserve.jl")
include("collections/thermal_plant.jl")
include("collections/virtual_reservoir.jl")
include("collections/zone.jl")

include("args.jl")

include("external_time_series/abstractions.jl")
include("external_time_series/utils.jl")
include("external_time_series/bids_view.jl")
include("external_time_series/time_series_view.jl")
include("external_time_series/ex_ante_and_ex_post_views.jl")
include("external_time_series/hour_block_mapping.jl")
include("external_time_series/virtual_reservoir_bids_view.jl")
include("external_time_series/time_series_views_from_external_files.jl")
include("external_time_series/block_aggregations.jl")
include("external_time_series/caching_implementations/flexible_demand.jl")

include("inputs.jl")
include("outputs.jl")
include("inflow.jl")

include("plots/plots.jl")
include("plots/time_series_mean.jl")
include("plots/time_series_all.jl")
include("plots/time_series_quantiles.jl")
include("plots/technology_histogram.jl")
include("plots/technology_histogram_stage.jl")
include("plots/technology_histogram_stage_block.jl")
include("plots/technology_histogram_block.jl")

include("utils.jl")
include("mathematical_model.jl")
include("graph_utils.jl")
include("sddp.jl")
include("bids.jl")
include("debugging_utils.jl")
include("clearing_utils.jl")
include("virtual_reservoir.jl")
include("main.jl")

include.(readdir(joinpath(@__DIR__, "model_variables"); join = true))
include.(readdir(joinpath(@__DIR__, "model_constraints"); join = true))
include.(readdir(joinpath(@__DIR__, "post_processing"); join = true))

end # module
