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
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    settlement_type = IARA.Configurations_SettlementType.DUAL,
    bid_data_source = IARA.Configurations_BidDataSource.READ_FROM_FILE,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "Zona")
IARA.add_bus!(db; label = "Sistema", zone_id = "Zona")

IARA.add_asset_owner!(db; label = "Agente A")
IARA.add_asset_owner!(db; label = "Agente B")
IARA.add_asset_owner!(db; label = "Agente C")
IARA.add_asset_owner!(db; label = "Agente D")
IARA.add_asset_owner!(db; label = "Agente E")

IARA.add_bidding_group!(
    db;
    label = "a",
    assetowner_id = "Agente A",
)

IARA.add_bidding_group!(
    db;
    label = "b",
    assetowner_id = "Agente B",
)

IARA.add_bidding_group!(
    db;
    label = "c",
    assetowner_id = "Agente C",
)

IARA.add_bidding_group!(
    db;
    label = "d",
    assetowner_id = "Agente D",
)

IARA.add_bidding_group!(
    db;
    label = "e",
    assetowner_id = "Agente E",
)

IARA.add_thermal_unit!(
    db;
    label = "Termica 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [40.0],
    ),
    biddinggroup_id = "a",
    bus_id = "Sistema",
)

IARA.add_thermal_unit!(
    db;
    label = "Termica 2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [45.0],
    ),
    biddinggroup_id = "b",
    bus_id = "Sistema",
)

IARA.add_thermal_unit!(
    db;
    label = "Termica 3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [60.0],
    ),
    biddinggroup_id = "c",
    bus_id = "Sistema",
)

IARA.add_thermal_unit!(
    db;
    label = "Termica 4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [75.0],
    ),
    biddinggroup_id = "d",
    bus_id = "Sistema",
)

IARA.add_thermal_unit!(
    db;
    label = "Termica 5",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [80.0],
    ),
    biddinggroup_id = "e",
    bus_id = "Sistema",
)

max_demand = 200.0
IARA.add_demand_unit!(
    db;
    label = "Demanda",
    max_demand = max_demand,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Sistema",
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
    labels = ["Demanda"],
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
number_of_bidding_groups = 5
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

quantity_offer[1, :, :, :, :, :] .= 60
quantity_offer[2, :, :, :, :, :] .= 60
quantity_offer[3, :, :, :, :, :] .= 60
quantity_offer[4, :, :, :, :, :] .= 60
quantity_offer[5, :, :, :, :, :] .= 60
price_offer[1, :, :, :, :, :] .= 40.0
price_offer[2, :, :, :, :, :] .= 45.0
price_offer[3, :, :, :, :, :] .= 60.0
price_offer[4, :, :, :, :, :] .= 75.0
price_offer[5, :, :, :, :, :] .= 80.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["a", "b", "c", "d", "e"],
    labels_buses = ["Sistema"],
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
    labels_bidding_groups = ["a", "b", "c", "d", "e"],
    labels_buses = ["Sistema"],
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
