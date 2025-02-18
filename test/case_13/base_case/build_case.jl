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
number_of_periods = 5
number_of_scenarios = 1
number_of_subscenarios = 4
number_of_subperiods = 2
subperiod_duration_in_hours = 1.0

# Conversion constants
# --------------------
MW_to_GWh = subperiod_duration_in_hours * 1e-3
m3_per_second_to_hm3 = (3600 / 1e6) * subperiod_duration_in_hours

# Create the database
# -------------------

db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    number_of_subscenarios = number_of_subscenarios,
    initial_date_time = "2024-01-01",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    demand_deficit_cost = 500.0,
    cycle_discount_rate = 0.0,
    clearing_hydro_representation = IARA.Configurations_ClearingHydroRepresentation.PURE_BIDS,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    settlement_type = IARA.Configurations_SettlementType.EX_POST,
    bid_data_source = IARA.Configurations_BidDataSource.READ_FROM_FILE,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "Zone 1")
IARA.add_bus!(db; label = "Bus 1", zone_id = "Zone 1")

IARA.add_asset_owner!(db; label = "Thermal Owner 1")
IARA.add_asset_owner!(db; label = "Thermal Owner 2")
IARA.add_asset_owner!(db; label = "Thermal Owner 3")

IARA.add_bidding_group!(
    db;
    label = "Bidding Group 1",
    assetowner_id = "Thermal Owner 1",
)

IARA.add_bidding_group!(
    db;
    label = "Bidding Group 2",
    assetowner_id = "Thermal Owner 2",
)

IARA.add_bidding_group!(
    db;
    label = "Bidding Group 3",
    assetowner_id = "Thermal Owner 3",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [100.0],
        om_cost = [40.0],
    ),
    biddinggroup_id = "Bidding Group 1",
    bus_id = "Bus 1",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal 2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [100.0],
        om_cost = [50.0],
    ),
    biddinggroup_id = "Bidding Group 2",
    bus_id = "Bus 1",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal 3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [100.0],
        om_cost = [65.0],
    ),
    biddinggroup_id = "Bidding Group 3",
    bus_id = "Bus 1",
)

max_demand = 200.0
IARA.add_demand_unit!(
    db;
    label = "Demand 1",
    max_demand = max_demand,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Bus 1",
)

demand_ex_post = zeros(1, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
demand_ex_post[:, 1, 1, :, :] .= 80 / max_demand
demand_ex_post[:, 2, 1, :, :] .= 150 / max_demand
demand_ex_post[:, 1, 2, :, :] .= 80 / max_demand
demand_ex_post[:, 2, 2, :, :] .= 220 / max_demand
demand_ex_post[:, 1, 3, :, :] .= 150 / max_demand
demand_ex_post[:, 2, 3, :, :] .= 150 / max_demand
demand_ex_post[:, 1, 4, :, :] .= 150 / max_demand
demand_ex_post[:, 2, 4, :, :] .= 220 / max_demand

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    demand_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Demand 1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2024-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_post = "demand_ex_post",
)

number_of_buses = 1
number_of_bidding_groups = 3
maximum_number_of_bidding_segments = 1
quantity_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
price_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )

quantity_offer[1, :, :, :, :, :] .= 100
quantity_offer[2, :, :, :, :, :] .= 100
quantity_offer[3, :, :, :, :, :] .= 100
price_offer[1, :, :, :, :, :] .= 41.0
price_offer[2, :, :, :, :, :] .= 51.0
price_offer[3, :, :, :, :, :] .= 65.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Bidding Group 1", "Bidding Group 2", "Bidding Group 3"],
    labels_buses = ["Bus 1"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2024-01-01T00:00:00",
    unit = "MWh",
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Bidding Group 1", "Bidding Group 2", "Bidding Group 3"],
    labels_buses = ["Bus 1"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2024-01-01T00:00:00",
    unit = "\$/MWh",
)
IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer = "quantity_offer",
    price_offer = "price_offer",
)
