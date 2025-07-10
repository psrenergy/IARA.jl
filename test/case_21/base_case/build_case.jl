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
    market_clearing_tiebreaker_weight = 1e-6,
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
IARA.add_asset_owner!(db; label = "Agente Portfolio")
IARA.add_asset_owner!(db; label = "Agente Termico")
IARA.add_asset_owner!(db; label = "Agente Renovavel")

# BG
IARA.add_bidding_group!(
    db;
    label = "Portfolio",
    assetowner_id = "Agente Portfolio",
    risk_factor = [0.1],
    segment_fraction = [1.0],
    fixed_cost = 1500.0,
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)
IARA.add_bidding_group!(
    db;
    label = "Termico",
    assetowner_id = "Agente Termico",
    risk_factor = [0.1],
    segment_fraction = [1.0],
    fixed_cost = 200.0,
)
IARA.add_bidding_group!(
    db;
    label = "Renovavel",
    assetowner_id = "Agente Renovavel",
    risk_factor = [0.1],
    segment_fraction = [1.0],
    fixed_cost = 2000.0,
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
)

# Thermal units
IARA.add_thermal_unit!(
    db;
    label = "Termica 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [70.0],
        om_cost = [80.0],
    ),
    biddinggroup_id = "Termico",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Termica 2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [40.0],
        om_cost = [130.0],
    ),
    biddinggroup_id = "Portfolio",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Termica 3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [30.0],
        om_cost = [200.0],
    ),
    biddinggroup_id = "Termico",
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
    biddinggroup_id = "Portfolio",
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
    biddinggroup_id = "Renovavel",
    bus_id = "Sistema",
)
IARA.add_renewable_unit!(db;
    label = "Eolica 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [50.0],
        om_cost = [10.0],
        curtailment_cost = [0.0],
    ),
    biddinggroup_id = "Renovavel",
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
demand_scenarios = [100.0, 125.0, 150.0, 175.0]
demand_ex_post =
    zeros(number_of_buses, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
for subscenario in 1:number_of_subscenarios
    demand_ex_post[:, :, subscenario, :, :] .= demand_scenarios[subscenario] / max_demand
end

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
    labels = ["Solar 1", "Solar 2", "Eolica 1"],
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
maximum_number_of_bidding_segments = 5
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

# --------------------------------------------------------------------------------
# Agente Portfolio
# --------------------------------------------------------------------------------
bidding_group_index = 1
# Solar 1
# ----------------
# Bid lowest scenario at O&M cost
bid_segment = 1
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 20.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 3.0
# Bid expected generation at an intermediate price
bid_segment = 2
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 30.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 50.0
# Bid highest scenario at a higher price
bid_segment = 3
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 30.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 100.0
# Termica 2
# ----------------
# Bid 30% of capacity at O&M cost
bid_segment = 4
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 15.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 130.0
# Bid 30% of capacity at a markup
bid_segment = 5
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 15.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 150.0
# The remaining capacity is not offered to hedge for lower solar generation scenarios

# --------------------------------------------------------------------------------
# Agente Termico
# --------------------------------------------------------------------------------
bidding_group_index = 2
# Termica 1
# ----------------
# Bid 30% of capacity at O&M cost
bid_segment = 1
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 21.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 80.0
# Bid 30% of capacity at a 10% markup
bid_segment = 2
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 21.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 88.0
# Bid 40% of capacity at a higher markup
bid_segment = 3
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 28.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 125.0
# Termica 3
# ----------------
# Bid capacity at O&M cost
bid_segment = 4
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 30.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 200.0

# --------------------------------------------------------------------------------
# Agente Renovavel
# --------------------------------------------------------------------------------
bidding_group_index = 3
# Solar 2
# ----------------
# Bid 70% of expected generation at O&M cost
bid_segment = 1
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 21.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 5.0
# Bid 30% of expected generation at a markup
bid_segment = 2
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 9.0
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 60.0
# Eolica 1
# ----------------
# Bid 70% of expected generation at O&M cost
bid_segment = 3
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 17.5
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 10.0
# Bid 30% of expected generation at a markup
bid_segment = 4
quantity_offer[bidding_group_index, :, bid_segment, :, :, :] .= 7.5
price_offer[bidding_group_index, :, bid_segment, :, :, :] .= 70.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfolio", "Termico", "Renovavel"],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "MW",
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfolio", "Termico", "Renovavel"],
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

# No-markup bids
# --------------
no_markup_price_offer = zeros(
    number_of_bidding_groups,
    number_of_buses,
    maximum_number_of_bidding_segments,
    number_of_subperiods,
    number_of_scenarios,
    1, # number of periods for reference price is always 1
)
no_markup_energy_offer = zeros(
    number_of_bidding_groups,
    number_of_buses,
    maximum_number_of_bidding_segments,
    number_of_subperiods,
    number_of_scenarios,
    1, # number of periods for reference price is always 1
)

# Agente Portfolio
# ----------------
bidding_group_index = 1
# Solar 1
no_markup_energy_offer[bidding_group_index, :, 1, :, :, :] .= 50.0
no_markup_price_offer[bidding_group_index, :, 1, :, :, :] .= 3.0
# Termica 2
no_markup_energy_offer[bidding_group_index, :, 2, :, :, :] .= 40.0
no_markup_price_offer[bidding_group_index, :, 2, :, :, :] .= 130.0
# Agente Termico
# ----------------
bidding_group_index = 2
# Termica 1
no_markup_energy_offer[bidding_group_index, :, 1, :, :, :] .= 70.0
no_markup_price_offer[bidding_group_index, :, 1, :, :, :] .= 80.0
# Termica 3
no_markup_energy_offer[bidding_group_index, :, 2, :, :, :] .= 30.0
no_markup_price_offer[bidding_group_index, :, 2, :, :, :] .= 200.0
# Agente Renovavel
# ----------------
bidding_group_index = 3
# Solar 2
no_markup_energy_offer[bidding_group_index, :, 1, :, :, :] .= 30.0
no_markup_price_offer[bidding_group_index, :, 1, :, :, :] .= 5.0
# Eolica 1
no_markup_energy_offer[bidding_group_index, :, 2, :, :, :] .= 25.0
no_markup_price_offer[bidding_group_index, :, 2, :, :, :] .= 10.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_no_markup_energy_offer_period_1"),
    no_markup_energy_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfolio", "Termico", "Renovavel"],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        1, # number of periods for reference price is always 1
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "MW",
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_no_markup_price_offer_period_1"),
    no_markup_price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfolio", "Termico", "Renovavel"],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        1, # number of periods for reference price is always 1
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.close_study!(db)
