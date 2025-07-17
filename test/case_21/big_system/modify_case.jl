#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = IARA.load_study(PATH; read_only = false)

IARA.add_asset_owner!(db; label = "Agente Portfolio 2")
IARA.add_asset_owner!(db; label = "Agente Termico 2")
IARA.add_asset_owner!(db; label = "Agente Renovavel 2")

# BG
IARA.add_bidding_group!(
    db;
    label = "Portfolio 2",
    assetowner_id = "Agente Portfolio 2",
    risk_factor = [0.1],
    segment_fraction = [1.0],
    fixed_cost = 1500.0,
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)
IARA.add_bidding_group!(
    db;
    label = "Termico 2",
    assetowner_id = "Agente Termico 2",
    risk_factor = [0.1],
    segment_fraction = [1.0],
    fixed_cost = 200.0,
)
IARA.add_bidding_group!(
    db;
    label = "Renovavel 2",
    assetowner_id = "Agente Renovavel 2",
    risk_factor = [0.1],
    segment_fraction = [1.0],
    fixed_cost = 2000.0,
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.PROPORTIONAL_TO_EX_POST_GENERATION_OVER_EX_ANTE_BID,
)

# Thermal units
IARA.add_thermal_unit!(
    db;
    label = "Termica 4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [70.0],
        om_cost = [80.0],
    ),
    biddinggroup_id = "Termico 2",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Termica 5",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [40.0],
        om_cost = [130.0],
    ),
    biddinggroup_id = "Portfolio 2",
    bus_id = "Sistema",
)
IARA.add_thermal_unit!(
    db;
    label = "Termica 6",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [30.0],
        om_cost = [200.0],
    ),
    biddinggroup_id = "Termico 2",
    bus_id = "Sistema",
)

# Renewable units
IARA.add_renewable_unit!(db;
    label = "Solar 3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [100.0],
        om_cost = [3.0],
        curtailment_cost = [0.0],
    ),
    biddinggroup_id = "Portfolio 2",
    bus_id = "Sistema",
)
IARA.add_renewable_unit!(db;
    label = "Solar 4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [60.0],
        om_cost = [5.0],
        curtailment_cost = [0.0],
    ),
    biddinggroup_id = "Renovavel 2",
    bus_id = "Sistema",
)
IARA.add_renewable_unit!(db;
    label = "Eolica 2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [50.0],
        om_cost = [10.0],
        curtailment_cost = [0.0],
    ),
    biddinggroup_id = "Renovavel 2",
    bus_id = "Sistema",
)

# Demand unit
max_demand *= 2
IARA.update_demand_unit!(db, "Demanda"; max_demand = max_demand)

# Time series data
# ----------------
# Renewable generation
new_renewable_generation_ex_post = cat(renewable_generation_ex_post, renewable_generation_ex_post; dims = 1)

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation_ex_post"),
    new_renewable_generation_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Solar 1", "Solar 2", "Eolica 1", "Solar 3", "Solar 4", "Eolica 2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)

# Bids
new_quantity_bid = cat(quantity_bid, quantity_bid; dims = 1)
new_price_bid = cat(price_bid, price_bid; dims = 1)
IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_bid"),
    new_quantity_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfolio", "Termico", "Renovavel", "Portfolio 2", "Termico 2", "Renovavel 2"],
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
    joinpath(PATH, "price_bid"),
    new_price_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfolio", "Termico", "Renovavel", "Portfolio 2", "Termico 2", "Renovavel 2"],
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

# No-markup bids
# --------------
new_no_markup_price_bid = cat(no_markup_price_bid, no_markup_price_bid; dims = 1)
new_no_markup_energy_bid = cat(no_markup_energy_bid, no_markup_energy_bid; dims = 1)
IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_no_markup_energy_bid_period_1"),
    new_no_markup_energy_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfolio", "Termico", "Renovavel", "Portfolio 2", "Termico 2", "Renovavel 2"],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        1, # number of periods for reference price is always 1
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "MWh",
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_no_markup_price_bid_period_1"),
    new_no_markup_price_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Portfolio", "Termico", "Renovavel", "Portfolio 2", "Termico 2", "Renovavel 2"],
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
