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
number_of_subscenarios = 4
number_of_subperiods = 1
subperiod_duration_in_hours = 1.0

number_of_buses = 1
number_of_bidding_groups = 8
number_of_thermal_units = 8
number_of_bg_segments = 1
number_of_asset_owners = 8

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
    settlement_type = IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    language = "pt",
    market_clearing_tiebreaker_weight_for_om_costs = 0.0,
    bid_processing = IARA.Configurations_BidProcessing.READ_BIDS_FROM_FILE,
    bid_price_limit_low_reference = 10.0,
    bid_price_limit_markup_non_justified_independent = 0.5,
    bid_price_limit_markup_justified_independent = 1.5,
    bid_price_validation = IARA.Configurations_BidPriceValidation.VALIDATE_WITH_DEFAULT_LIMIT,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "Zona")
IARA.add_bus!(db; label = "Sistema", zone_id = "Zona")

# AO
IARA.add_asset_owner!(db; label = "Agente Termico 1", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Termico 2", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Termico 3", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Termico 4", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Peaker 1", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Peaker 2", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Peaker 3", purchase_discount_rate = [0.1])
IARA.add_asset_owner!(db; label = "Agente Peaker 4", purchase_discount_rate = [0.1])

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
    label = "Termico 4",
    assetowner_id = "Agente Termico 4",
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
IARA.add_bidding_group!(
    db;
    label = "Peaker 4",
    assetowner_id = "Agente Peaker 4",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_bid = "bidding_group_energy_bid",
    price_bid = "bidding_group_price_bid",
)

bg_quantity_bid =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        number_of_bg_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )

bg_price_bid =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        number_of_bg_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )

IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_energy_bid"),
    bg_quantity_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = [
        "Termico 1",
        "Termico 2",
        "Termico 3",
        "Termico 4",
        "Peaker 1",
        "Peaker 2",
        "Peaker 3",
        "Peaker 4",
    ],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        number_of_bg_segments,
    ],
    initial_date = "2025-01-01",
    unit = "MWh",
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_price_bid"),
    bg_price_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = [
        "Termico 1",
        "Termico 2",
        "Termico 3",
        "Termico 4",
        "Peaker 1",
        "Peaker 2",
        "Peaker 3",
        "Peaker 4",
    ],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        number_of_bg_segments,
    ],
    initial_date = "2025-01-01",
    unit = "\$/MWh",
)

# Build bid justifications file
justifications = []
for period in 1:number_of_periods
    period_justification = Dict(
        "period" => period,
        "justifications" => Dict(
            "Termico 1" => "foo bar baz",
            "Termico 2" => "foo bar baz",
            "Termico 3" => "foo bar baz",
            "Termico 4" => "foo bar baz",
            "Peaker 1" => "foo bar baz",
            "Peaker 2" => "foo bar baz",
            "Peaker 3" => "foo bar baz",
            "Peaker 4" => "foo bar baz",
        ),
    )
    push!(justifications, period_justification)
end

open(joinpath(PATH, "bid_justifications.json"), "w") do file
    return write(file, IARA.JSON.json(justifications))
end

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    bid_justifications = "bid_justifications.json",
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
    label = "Termica 4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [95.0],
        om_cost = [100.0],
    ),
    biddinggroup_id = "Termico 4",
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
IARA.add_thermal_unit!(
    db;
    label = "Peaker 4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [200.0],
    ),
    biddinggroup_id = "Peaker 4",
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
demand_ex_post = [260.0, 330.0, 400.0, 470.0]

demand_factor_ex_post =
    zeros(number_of_buses, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
for subscenario in 1:number_of_subscenarios
    demand_factor_ex_post[:, :, subscenario, :, :] .= demand_ex_post[subscenario] / max_demand
end

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
