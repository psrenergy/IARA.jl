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
number_of_periods = 10
number_of_scenarios = 1
number_of_subscenarios = 4
number_of_subperiods = 1
subperiod_duration_in_hours = 1.0

number_of_buses = 1
number_of_bidding_groups = 3
number_of_thermal_units = 3
number_of_renewable_units = 3

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
    initial_date_time = "2025-01-01",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    demand_deficit_cost = 500.0,
    cycle_discount_rate = 0.0,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    settlement_type = IARA.Configurations_SettlementType.DOUBLE,
    bid_data_source = IARA.Configurations_BidDataSource.READ_FROM_FILE,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    language = "pt",
    market_clearing_tiebreaker_weight = 0.0,
    bidding_group_bid_validation = IARA.Configurations_BiddingGroupBidValidation.VALIDATE,
    bid_price_limit_low_reference = 100.0,
    bid_price_limit_markup_non_justified_independent = 0.2,
    bid_price_limit_markup_justified_independent = 1.0,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "Zona")
IARA.add_bus!(db; label = "Sistema", zone_id = "Zona")

# AO
IARA.add_asset_owner!(db; label = "Agente Portfólio")
IARA.add_asset_owner!(db; label = "Agente Térmico")
IARA.add_asset_owner!(db; label = "Agente Renovável")

# BG
IARA.add_bidding_group!(
    db;
    label = "Portfólio",
    assetowner_id = "Agente Portfólio",
    risk_factor = [0.1],
    segment_fraction = [1.0],
    fixed_cost = 300.0,
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)
IARA.add_bidding_group!(
    db;
    label = "Térmico",
    assetowner_id = "Agente Térmico",
    risk_factor = [0.1],
    segment_fraction = [1.0],
    fixed_cost = 100.0,
)
IARA.add_bidding_group!(
    db;
    label = "Renovável",
    assetowner_id = "Agente Renovável",
    risk_factor = [0.1],
    segment_fraction = [1.0],
    fixed_cost = 1000.0,
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
)

# Thermal units
IARA.add_thermal_unit!(
    db;
    label = "Térmica 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [70.0],
        om_cost = [80.0],
    ),
    biddinggroup_id = "Térmico",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Térmica 2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [40.0],
        om_cost = [130.0],
    ),
    biddinggroup_id = "Portfólio",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Térmica 3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [30.0],
        om_cost = [200.0],
    ),
    biddinggroup_id = "Térmico",
    bus_id = "Sistema",
)

# Renewable units
IARA.add_renewable_unit!(db;
    label = "Solar 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [100.0],
        om_cost = [3.0],
        curtailment_cost = [0.0],
    ),
    biddinggroup_id = "Portfólio",
    bus_id = "Sistema",
)
IARA.add_renewable_unit!(db;
    label = "Solar 2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [5.0],
        curtailment_cost = [0.0],
    ),
    biddinggroup_id = "Renovável",
    bus_id = "Sistema",
)
IARA.add_renewable_unit!(db;
    label = "Eólica 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [50.0],
        om_cost = [10.0],
        curtailment_cost = [0.0],
    ),
    biddinggroup_id = "Renovável",
    bus_id = "Sistema",
)

# Demand unit
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

# Time series data
# ----------------
# Demand
low_demand = 100.0
high_demand = 150.0
low_demand_scenarios = [1, 2]
high_demand_scenarios = [3, 4]
demand_ex_post =
    zeros(number_of_buses, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
demand_ex_post[:, :, low_demand_scenarios, :, :] .= low_demand / max_demand
demand_ex_post[:, :, high_demand_scenarios, :, :] .= high_demand / max_demand

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    demand_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Demanda"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)
IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_post = "demand_ex_post",
)

# Renewable generation
solar_1_generation_scenarios = [0.8, 0.5, 0.5, 0.2]
solar_2_generation_scenarios = [0.9, 0.8, 0.2, 0.1]
eolica_1_generation_scenarios = [0.2, 0.4, 0.6, 0.8]
renewable_generation_ex_post =
    zeros(3, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
for subscenario in 1:number_of_subscenarios
    renewable_generation_ex_post[1, :, subscenario, :, :] .= solar_1_generation_scenarios[subscenario]
    renewable_generation_ex_post[2, :, subscenario, :, :] .= solar_2_generation_scenarios[subscenario]
    renewable_generation_ex_post[3, :, subscenario, :, :] .= eolica_1_generation_scenarios[subscenario]
end

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation_ex_post"),
    renewable_generation_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Solar 1", "Solar 2", "Eólica 1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)
IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_post = "renewable_generation_ex_post",
)

# Bids
maximum_number_of_bidding_segments = 2
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

# Agente Portfólio
# ----------------
# Termica 2
quantity_offer[1, :, 1, :, :, :] .= 40.0
price_offer[1, :, 1, :, :, :] .= 130.0
# Solar 1
quantity_offer[1, :, 2, :, :, :] .= 50.0
price_offer[1, :, 2, :, :, :] .= 3.0
# Agente Termico
# ----------------
# Termica 1
quantity_offer[2, :, 1, :, :, :] .= 70.0
price_offer[2, :, 1, :, :, :] .= 80.0
# Termica 3
quantity_offer[2, :, 2, :, :, :] .= 30.0
price_offer[2, :, 2, :, :, :] .= 200.0
# Agente Renovável
# ----------------
# Solar 2
quantity_offer[3, :, 1, :, :, :] .= 30.0
price_offer[3, :, 1, :, :, :] .= 5.0
# Eólica 1
quantity_offer[3, :, 2, :, :, :] .= 25.0
price_offer[3, :, 2, :, :, :] .= 10.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfólio", "Térmico", "Renovável"],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "MWh",
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfólio", "Térmico", "Renovável"],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)
IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer = "quantity_offer",
    price_offer = "price_offer",
)

IARA.close_study!(db)
