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
number_of_subscenarios = 3
number_of_subperiods = 1
subperiod_duration_in_hours = 1.0

# Conversion constants
# --------------------
MW_to_GWh = subperiod_duration_in_hours * 1e-3
m3_per_second_to_hm3 = (3600 / 1e6) * subperiod_duration_in_hours

# Create the database
# -------------------

db = IARA.create_study!(PATH;
    language = "pt",
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    number_of_subscenarios = number_of_subscenarios,
    initial_date_time = "2024-01-01",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    demand_deficit_cost = 200.0,
    cycle_discount_rate = 0.0,
    clearing_hydro_representation = IARA.Configurations_VirtualReservoirBidProcessing.IGNORE_VIRTUAL_RESERVOIRS,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    settlement_type = IARA.Configurations_FinancialSettlementType.EX_POST,
    bid_data_processing = IARA.Configurations_BiddingGroupBidProcessing.EXTERNAL_UNVALIDATED_BID,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    market_clearing_tiebreaker_weight = 0.0,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "Zona")
IARA.add_bus!(db; label = "Sistema", zone_id = "Zona")

IARA.add_asset_owner!(db; label = "Agente Azul")
IARA.add_asset_owner!(db; label = "Agente Vermelho")
IARA.add_asset_owner!(db; label = "Agente Verde")
IARA.add_asset_owner!(db; label = "Agente Roxo")
IARA.add_asset_owner!(db; label = "Agente Amarelo")

IARA.add_bidding_group!(
    db;
    label = "Vermelho",
    assetowner_id = "Agente Vermelho",
    risk_factor = [0.1],
    segment_fraction = [1.0],
)

IARA.add_bidding_group!(
    db;
    label = "Verde",
    assetowner_id = "Agente Verde",
    risk_factor = [0.1],
    segment_fraction = [1.0],
)

IARA.add_bidding_group!(
    db;
    label = "Amarelo",
    assetowner_id = "Agente Amarelo",
    risk_factor = [0.1],
    segment_fraction = [1.0],
)

IARA.add_bidding_group!(
    db;
    label = "Azul",
    assetowner_id = "Agente Azul",
    risk_factor = [0.1],
    segment_fraction = [1.0],
)

IARA.add_bidding_group!(
    db;
    label = "Roxo",
    assetowner_id = "Agente Roxo",
    risk_factor = [0.1],
    segment_fraction = [1.0],
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
    biddinggroup_id = "Vermelho",
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
    biddinggroup_id = "Verde",
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
    biddinggroup_id = "Amarelo",
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
    biddinggroup_id = "Azul",
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
    biddinggroup_id = "Roxo",
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
demand_ex_post[:, :, 1, :, :] .= 80 / max_demand
demand_ex_post[:, :, 2, :, :] .= 150 / max_demand
demand_ex_post[:, :, 3, :, :] .= 220 / max_demand

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
quantity_bid =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
price_bid =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )

quantity_bid[1, :, :, :, :, :] .= 60
quantity_bid[2, :, :, :, :, :] .= 60
quantity_bid[3, :, :, :, :, :] .= 60
quantity_bid[4, :, :, :, :, :] .= 60
quantity_bid[5, :, :, :, :, :] .= 60
price_bid[1, :, :, :, :, :] .= 40.0
price_bid[2, :, :, :, :, :] .= 45.0
price_bid[3, :, :, :, :, :] .= 60.0
price_bid[4, :, :, :, :, :] .= 75.0
price_bid[5, :, :, :, :, :] .= 80.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_bid"),
    quantity_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Vermelho", "Verde", "Amarelo", "Azul", "Roxo"],
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
    joinpath(PATH, "price_bid"),
    price_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Vermelho", "Verde", "Amarelo", "Azul", "Roxo"],
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
    quantity_bid = "quantity_bid",
    price_bid = "price_bid",
)
