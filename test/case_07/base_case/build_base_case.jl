#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

using Dates
using DataFrames

# Case dimensions
# ---------------
number_of_stages = 3
number_of_scenarios = 2
number_of_blocks = 4
maximum_number_of_bidding_segments = 1
block_duration_in_hours = 1000.0 / number_of_blocks

# Conversion factors
MW_to_GWh = block_duration_in_hours * 1e-3
m3_per_second_to_hm3_per_hour = 3600.0 / 1e6

# Create the database
# -------------------
db = nothing
GC.gc()
GC.gc()

db = create_study!(PATH;
    number_of_stages = number_of_stages,
    number_of_scenarios = number_of_scenarios,
    number_of_blocks = number_of_blocks,
    initial_date_time = "2020",
    block_duration_in_hours = [block_duration_in_hours for _ in 1:number_of_blocks],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    yearly_discount_rate = 0.0,
    yearly_duration_in_hours = 8760.0,
    demand_deficit_cost = 500.0,
    run_mode = IARA.Configurations_RunMode.MARKET_CLEARING,
    hydro_minimum_outflow_violation_cost = 600.0,
    number_of_virtual_reservoir_bidding_segments = maximum_number_of_bidding_segments,
    clearing_hydro_representation = Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS,
    clearing_bid_source = Configurations_ClearingBidSource.HEURISTIC_BIDS,
)

# Add collection elements
# -----------------------

add_zone!(db; label = "zone_1")

add_bus!(db; label = "bus_1", zone_id = "zone_1")

add_hydro_plant!(db;
    label = "hydro_1",
    initial_volume = 900.0,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        production_factor = 1000.0 * m3_per_second_to_hm3_per_hour,
        max_generation = 400.0,
        min_volume = 0.0,
        max_turbining = 400.0 / m3_per_second_to_hm3_per_hour, # maybe it is 0.4 instead of 400
        max_volume = 2000.0,
        min_outflow = 0.3 / m3_per_second_to_hm3_per_hour,
        om_cost = 10.0,
    ),
)

add_hydro_plant!(db;
    label = "hydro_2",
    initial_volume = 0.0,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        production_factor = 1000.0 * m3_per_second_to_hm3_per_hour,
        max_generation = 700.0,
        max_turbining = 700.0 / m3_per_second_to_hm3_per_hour,
        min_volume = 0.0,
        max_volume = 0.0,
        min_outflow = 0.0,
        om_cost = 10.0,
    ),
)

set_hydro_turbine_to!(db, "hydro_1", "hydro_2")
set_hydro_spill_to!(db, "hydro_1", "hydro_2")

add_asset_owner!(db;
    label = "asset_owner_1",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
    segment_fraction = [0.2, 0.8],
    risk_factor = [0.1, 0.2],
)

add_asset_owner!(db;
    label = "asset_owner_2",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)

add_virtual_reservoir!(db;
    label = "reservoir_1",
    assetowner_id = ["asset_owner_1", "asset_owner_2"],
    inflow_allocation = [0.5, 0.5],
    hydroplant_id = ["hydro_1", "hydro_2"],
)

add_demand!(db;
    label = "dem_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "bus_1",
)

demand = zeros(1, number_of_blocks, number_of_scenarios, number_of_stages)
demand[1, :, 1, :] .= 150.0
demand[1, :, 2, :] .= 200.0
write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020",
    unit = "GWh",
)

link_time_series_to_file(
    db,
    "Demand";
    demand = "demand",
)

inflow = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages)
write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["stage", "scenario", "block"],
    labels = ["hydro_1_gauging_station", "hydro_2_gauging_station"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020",
    unit = "m3/s",
)

link_time_series_to_file(
    db,
    "HydroPlant";
    inflow = "inflow",
)

# Write hydro timeseries that usually come from a CENTRALIZED_OPERATION run.
# values were chosen to match an execution of this case with the run_mode changed to CENTRALIZED_OPERATION
hydro_generation = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages)
hydro_generation .= 75.0
hydro_generation[1, 4, 1, 1:2] .= 25.0
hydro_generation[2, 1:3, 1, 1:2] .= 25.0
hydro_generation[2, :, 1, 3] .= 25.0

hydro_opportunity_cost = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages)
hydro_opportunity_cost[1, :, :, :] .= 0.3
hydro_opportunity_cost[2, :, :, :] .= 0.6

write_timeseries_file(
    joinpath(PATH, "hydro_generation"),
    hydro_generation;
    dimensions = ["stage", "scenario", "block"],
    labels = ["hydro_1", "hydro_2"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

write_timeseries_file(
    joinpath(PATH, "hydro_opportunity_cost"),
    hydro_opportunity_cost;
    dimensions = ["stage", "scenario", "block"],
    labels = ["hydro_1", "hydro_2"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

close_study!(db)
