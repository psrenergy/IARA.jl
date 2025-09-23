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

# External packages
using ArgParse
using CSV
using DataFrames
using EnumX
using HiGHS
using JuMP
using LoggingPolyglot
using OrderedCollections
using ParametricOptInterface
using PeriodicAutoregressive
using PlotlyLight
using PSRBridge
using PSRClassesInterface
using Quiver
using Serialization
using SDDP
using StatsBase
using MemoizedSerialization
using JSON

# Julia std packages
using Dates
using LinearAlgebra
using Random
using Statistics
using Printf

const Log = LoggingPolyglot
const PSRI = PSRClassesInterface
const PSRDatabaseSQLite = PSRI.PSRDatabaseSQLite
const DatabaseSQLite = PSRI.PSRDatabaseSQLite.DatabaseSQLite
const POI = ParametricOptInterface

function initialize(args)
    # Initialize dlls and other possible defaults
    MemoizedSerialization.clean!(; max_size = 100_000)
    initialize_plotly()
    initialize_output_dir(args)
    initialize_logger(args)
    print_banner()
    return nothing
end

const COMPILED = Ref{Bool}(false)

function is_compiled()::Bool
    return COMPILED[]
end

include("version.jl")
include("path_utils.jl")

include("enumx.jl")
include("run_time_options.jl")
include("revenue_convex_hull.jl")

include("collections/abstract_collection.jl")
include("collections/asset_owner.jl")
include("collections/battery_unit.jl")
include("collections/bidding_group.jl")
include("collections/branch.jl")
include("collections/bus.jl")
include("collections/configurations.jl")
include("collections/dc_line.jl")
include("collections/demand_unit.jl")
include("collections/gauging_station.jl")
include("collections/hydro_unit.jl")
include("collections/interconnection.jl")
include("collections/renewable_unit.jl")
include("collections/thermal_unit.jl")
include("collections/virtual_reservoir.jl")
include("collections/zone.jl")

include("args.jl")
include("logs.jl")

include("external_time_series/abstractions.jl")
include("external_time_series/utils.jl")
include("external_time_series/bids_view.jl")
include("external_time_series/time_series_view.jl")
include("external_time_series/ex_ante_and_ex_post_views.jl")
include("external_time_series/hour_subperiod_mapping.jl")
include("external_time_series/virtual_reservoir_bids_view.jl")
include("external_time_series/time_series_views_from_external_files.jl")
include("external_time_series/subperiod_aggregations.jl")
include("external_time_series/caching_implementations/flexible_demand.jl")

include("inputs.jl")
include("outputs.jl")
include("inflow.jl")

include("plots/plots.jl")
include("plots/interface_input_plots.jl")
include("plots/interface_output_plots.jl")
include("plots/time_series_all.jl")
include("plots/time_series_quantiles.jl")
include("plots/technology_histogram.jl")
include("plots/technology_histogram_period.jl")
include("plots/technology_histogram_period_subperiod.jl")
include("plots/technology_histogram_subperiod.jl")
include("plots/time_series_stacked_mean.jl")
include("plots/custom_plot.jl")
include("plots/utils.jl")
include("plots/plot_strings.jl")

include("utils.jl")
include("mathematical_model.jl")
include("nash_equilibrium.jl")
include("graph_utils.jl")
include("sddp.jl")
include("bids.jl")
include("bid_validations.jl")
include("debugging_utils.jl")
include("clearing_utils.jl")
include("hydro_supply_reference_curve_utils.jl")
include("reference_curve_nash.jl")
include("virtual_reservoir.jl")
include("main.jl")

include.(readdir(joinpath(@__DIR__, "model_variables"); join = true))
include.(readdir(joinpath(@__DIR__, "model_constraints"); join = true))
include.(readdir(joinpath(@__DIR__, "post_processing"); join = true))

include("example_cases_builder.jl")
include("interface_calls/InterfaceCalls.jl")

end
