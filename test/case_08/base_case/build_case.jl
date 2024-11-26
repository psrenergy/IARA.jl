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
number_of_periods = 3
number_of_scenarios = 2
number_of_subperiods = 3
subperiod_duration_in_hours = 1.0

# Conversion constants
# --------------------
m3_per_second_to_hm3 = (3600 / 1e6) * subperiod_duration_in_hours
MW_to_GWh = subperiod_duration_in_hours * 1e-3

# Create the database
# -------------------

db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    initial_date_time = "2024-01-01",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    demand_deficit_cost = 500.0,
    cycle_discount_rate = 0.1,
    clearing_hydro_representation = IARA.Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS,
    clearing_model_type_ex_ante_physical = IARA.Configurations_ClearingModelType.HYBRID,
    clearing_model_type_ex_ante_commercial = IARA.Configurations_ClearingModelType.HYBRID,
    clearing_model_type_ex_post_physical = IARA.Configurations_ClearingModelType.HYBRID,
    clearing_model_type_ex_post_commercial = IARA.Configurations_ClearingModelType.HYBRID,
    clearing_bid_source = IARA.Configurations_ClearingBidSource.HEURISTIC_BIDS,
    number_of_virtual_reservoir_bidding_segments = 1,
    reservoirs_physical_virtual_correspondence_type = IARA.Configurations_ReservoirsPhysicalVirtualCorrespondenceType.BY_GENERATION,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

IARA.add_hydro_unit!(db;
    label = "hydro_1",
    initial_volume = 12.0 * m3_per_second_to_hm3,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1.0,
        max_generation = 3.5,
        max_turbining = 3.5,
        min_volume = 0.0,
        max_volume = 30.0 * m3_per_second_to_hm3,
        om_cost = 0.1,
    ),
)

IARA.add_hydro_unit!(db;
    label = "hydro_2",
    initial_volume = 12.0 * m3_per_second_to_hm3,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1.0,
        max_generation = 3.5,
        max_turbining = 3.5,
        min_volume = 0.0,
        max_volume = 30.0 * m3_per_second_to_hm3,
        om_cost = 0.1,
    ),
)

IARA.add_demand_unit!(db;
    label = "demand_1",
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.DemandUnit_Existence.EXISTS),
    ),
)

IARA.add_asset_owner!(db; label = "asset_owner_1")
IARA.add_asset_owner!(db; label = "asset_owner_2")

IARA.add_virtual_reservoir!(db;
    label = "virtual_reservoir_1",
    assetowner_id = ["asset_owner_1", "asset_owner_2"],
    inflow_allocation = [0.2, 0.8],
    hydrounit_id = ["hydro_1", "hydro_2"],
)

demand = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods) .+ 5.0 * MW_to_GWh
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["demand_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "GWh",
)
IARA.link_time_series_to_file(db, "DemandUnit"; demand = "demand")

inflow = [0.4 + 0.4s for h in 1:2, b in 1:number_of_subperiods, s in 1:number_of_scenarios, t in 1:number_of_periods]
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hydro_1_gauging_station", "hydro_2_gauging_station"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "m3/s",
)
IARA.link_time_series_to_file(db, "HydroUnit"; inflow = "inflow")

# Write hydro timeseries that usually come from a TRAIN_MIN_COST run.
# values were chosen to match an execution of this case with the run_mode changed to TRAIN_MIN_COST

hydro_generation = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods)
hydro_generation[:, :, :, 1:2] .= 2.5 * MW_to_GWh
hydro_generation[:, :, 1, 3] .= 1.4 * MW_to_GWh
IARA.write_timeseries_file(
    joinpath(PATH, "hydro_generation"),
    hydro_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hydro_1", "hydro_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "GWh",
)

IARA.close_study!(db)

hydro_opportunity_cost = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods)
hydro_opportunity_cost[:, :, 1, :] .= 491.198338
hydro_opportunity_cost[:, :, 2, 1] .= 368.398753
hydro_opportunity_cost[:, :, 2, 2] .= 245.599169
hydro_opportunity_cost[:, :, 2, 3] .= 0.0
IARA.write_timeseries_file(
    joinpath(PATH, "hydro_opportunity_cost"),
    hydro_opportunity_cost;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hydro_1", "hydro_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "\$/MWh",
)
