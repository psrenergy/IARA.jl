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
number_of_scenarios = 4
number_of_subperiods = 2
maximum_number_of_bidding_segments = 1
subperiod_duration_in_hours = 1.0
MW_to_GWh = subperiod_duration_in_hours * 1e-3

# Create the database
# -------------------

db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    initial_date_time = "2020-01-01T00:00:00",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    cycle_discount_rate = 0.0,
    cycle_duration_in_hours = 8760.0,
    demand_deficit_cost = 500.0,
    clearing_model_type_ex_ante_physical = IARA.Configurations_ClearingModelType.BID_BASED,
    clearing_model_type_ex_ante_commercial = IARA.Configurations_ClearingModelType.BID_BASED,
    clearing_model_type_ex_post_physical = IARA.Configurations_ClearingModelType.BID_BASED,
    clearing_model_type_ex_post_commercial = IARA.Configurations_ClearingModelType.BID_BASED,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")
IARA.add_bus!(db; label = "bus_2", zone_id = "zone_1")
number_of_buses = 2

IARA.add_asset_owner!(db;
    label = "asset_owner_1",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)
IARA.add_asset_owner!(db;
    label = "asset_owner_2",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)

IARA.add_bidding_group!(db;
    label = "bg_1",
    assetowner_id = "asset_owner_1",
    independent_bid_max_segments = maximum_number_of_bidding_segments,
)
IARA.add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_2",
    independent_bid_max_segments = maximum_number_of_bidding_segments,
)
number_of_bidding_groups = 2

IARA.add_demand_unit!(db;
    label = "dem_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
    ),
    bus_id = "bus_1",
)

IARA.add_dc_line!(db;
    label = "dc_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DCLine_Existence.EXISTS)],
        capacity_to = [5.5],
        capacity_from = [5.5],
    ),
    bus_from = "bus_1",
    bus_to = "bus_2",
)

# Create and link CSV files
# -------------------------
# Demand
demand = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods) .+ 10 * MW_to_GWh
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)
IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand = "demand",
)

# Quantity and price offers
quantity_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
for scenario in 1:number_of_scenarios
    quantity_offer[:, 1, 1, :, scenario, :] .= 6 - scenario
    for bg in 1:number_of_bidding_groups
        quantity_offer[bg, 2, 1, :, scenario, :] .= (bg / 2) * (scenario + 1)
    end
end
IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "MWh",
)

price_offer = zeros(
    number_of_bidding_groups,
    number_of_buses,
    maximum_number_of_bidding_segments,
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)
price_offer[1, 1, 1, :, :, :] .= 100
price_offer[2, 1, 1, :, :, :] .= 90
price_offer[1, 2, 1, :, :, :] .= 80
price_offer[2, 2, 1, :, :, :] .= 70
# TODO: revisar se é $/GWh
IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_segments,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)
IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer = "quantity_offer",
    price_offer = "price_offer",
)

IARA.close_study!(db)
