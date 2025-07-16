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
number_of_subperiods = 4
maximum_number_of_bidding_segments = 1
subperiod_duration_in_hours = 1000.0 / number_of_subperiods

# Conversion factors
m3_per_second_to_hm3_per_hour = 3600.0 / 1e6

# Create the database
# -------------------

db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    initial_date_time = "2020",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    cycle_discount_rate = 0.0,
    cycle_duration_in_hours = 8760.0,
    demand_deficit_cost = 500.0,
    hydro_minimum_outflow_violation_cost = 600.0,
    clearing_hydro_representation = IARA.Configurations_VirtualReservoirBidProcessing.HEURISTIC_BID_FROM_WATER_VALUES,
    bid_data_processing = IARA.Configurations_BiddingGroupBidProcessing.HEURISTIC_UNVALIDATED_BID,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    virtual_reservoir_correspondence_type = IARA.Configurations_VirtualReservoirCorrespondenceType.DELTA_CORRESPONDENCE_CONSTRAINT,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    reference_curve_number_of_segments = 10,
)

# Add collection elements
# -----------------------

IARA.add_zone!(db; label = "zone_1")

IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

IARA.add_hydro_unit!(db;
    label = "hydro_1",
    initial_volume = 900.0,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1000.0 * m3_per_second_to_hm3_per_hour,
        max_generation = 400.0,
        min_volume = 0.0,
        max_turbining = 400.0 / m3_per_second_to_hm3_per_hour, # maybe it is 0.4 instead of 400
        max_volume = 2000.0,
        min_outflow = 0.3 / m3_per_second_to_hm3_per_hour,
        om_cost = 10.0,
    ),
)

IARA.add_hydro_unit!(db;
    label = "hydro_2",
    initial_volume = 0.0,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1000.0 * m3_per_second_to_hm3_per_hour,
        max_generation = 700.0,
        max_turbining = 700.0 / m3_per_second_to_hm3_per_hour,
        min_volume = 0.0,
        max_volume = 0.0,
        min_outflow = 0.0,
        om_cost = 10.0,
    ),
)

IARA.set_hydro_turbine_to!(db, "hydro_1", "hydro_2")
IARA.set_hydro_spill_to!(db, "hydro_1", "hydro_2")

IARA.add_asset_owner!(db;
    label = "asset_owner_1",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
    virtual_reservoir_energy_account_upper_bound = [0.5, 1.0],
    risk_factor_for_virtual_reservoir_bids = [0.1, -0.1],
    purchase_discount_rate = 0.1,
)

IARA.add_asset_owner!(db;
    label = "asset_owner_2",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
    purchase_discount_rate = 0.1,
)

IARA.add_virtual_reservoir!(db;
    label = "reservoir_1",
    assetowner_id = ["asset_owner_1", "asset_owner_2"],
    inflow_allocation = [0.5, 0.5],
    hydrounit_id = ["hydro_1", "hydro_2"],
)

IARA.add_bidding_group!(db;
    label = "empty_bidding_group",
    assetowner_id = "asset_owner_1",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)

IARA.update_hydro_unit_relation!(db,
    "hydro_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "empty_bidding_group",
)

IARA.update_hydro_unit_relation!(db,
    "hydro_2";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "empty_bidding_group",
)

demand = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
demand[1, :, 1, :] .= 150.0
demand[1, :, 2, :] .= 200.0
max_demand = 200.0
demand ./= max_demand
demand .*= (1000 / subperiod_duration_in_hours)

IARA.add_demand_unit!(db;
    label = "dem_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
    ),
    bus_id = "bus_1",
    max_demand = max_demand,
)

IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demand",
)

inflow = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods)
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hydro_1", "hydro_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020",
    unit = "m3/s",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow_ex_ante = "inflow",
)

IARA.link_time_series_to_file(
    db,
    "Configuration";
    fcf_cuts = "cuts.json",
)

IARA.close_study!(db)
