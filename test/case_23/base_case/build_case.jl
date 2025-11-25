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
number_of_periods = 4
number_of_scenarios = 1
number_of_subscenarios = 1
number_of_subperiods = 1
subperiod_duration_in_hours = 1.0

number_of_buses = 1
number_of_bidding_groups = 6
number_of_thermal_units = 6
number_of_renewable_units = 0

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
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    settlement_type = IARA.Configurations_FinancialSettlementType.EX_POST,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    language = "pt",
    market_clearing_tiebreaker_weight_for_om_costs = 0.0,
    # bidding_group_bid_validation = IARA.Configurations_BiddingGroupBidValidation.DO_NOT_VALIDATE,
    bid_processing = IARA.Configurations_BidProcessing.PARAMETERIZED_HEURISTIC_BIDS,
    bid_price_limit_low_reference = 9999.0,
    bid_price_limit_markup_non_justified_independent = 9999.0,
    bid_price_limit_markup_justified_independent = 9999.0,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "Zona")
IARA.add_bus!(db; label = "Sistema", zone_id = "Zona")

# AO
IARA.add_asset_owner!(db; label = "Agente Termico 1", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Termico 2", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Termico 3", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Peaker 1", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Peaker 2", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Peaker 3", purchase_discount_rate = [0.1])

# BG
IARA.add_bidding_group!(
    db;
    label = "Termico 1",
    assetowner_id = "Agente Termico 1",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)
IARA.add_bidding_group!(
    db;
    label = "Termico 2",
    assetowner_id = "Agente Termico 2",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)
IARA.add_bidding_group!(
    db;
    label = "Termico 3",
    assetowner_id = "Agente Termico 3",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)
IARA.add_bidding_group!(
    db;
    label = "Peaker 1",
    assetowner_id = "Agente Peaker 1",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)
IARA.add_bidding_group!(
    db;
    label = "Peaker 2",
    assetowner_id = "Agente Peaker 2",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)
IARA.add_bidding_group!(
    db;
    label = "Peaker 3",
    assetowner_id = "Agente Peaker 3",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)

# Thermal units
IARA.add_thermal_unit!(
    db;
    label = "Termica 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [95.0],
        om_cost = [100.0],
    ),
    biddinggroup_id = "Termico 1",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Termica 2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [95.0],
        om_cost = [100.0],
    ),
    biddinggroup_id = "Termico 2",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Termica 3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [95.0],
        om_cost = [100.0],
    ),
    biddinggroup_id = "Termico 3",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Peaker 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [200.0],
    ),
    biddinggroup_id = "Peaker 1",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Peaker 2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [200.0],
    ),
    biddinggroup_id = "Peaker 2",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Peaker 3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [200.0],
    ),
    biddinggroup_id = "Peaker 3",
    bus_id = "Sistema",
)

# Demand unit
max_demand = 400.0
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
demand_ex_ante = [400.0, 460.0, 520.0, 580.0]
demand_ex_post = [350.0, 490.0, 530.0, 560.0]

demand_factor_ex_ante = zeros(number_of_buses, number_of_subperiods, number_of_scenarios, number_of_periods)
demand_factor_ex_post =
    zeros(number_of_buses, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
for period in 1:number_of_periods
    demand_factor_ex_ante[:, :, :, period] .= demand_ex_ante[period] / max_demand
    demand_factor_ex_post[:, :, :, :, period] .= demand_ex_post[period] / max_demand
end

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_ante"),
    demand_factor_ex_ante;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["Demanda"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demand_ex_ante",
)

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    demand_factor_ex_post;
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

IARA.close_study!(db)
