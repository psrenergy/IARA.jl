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

maximum_number_of_bidding_profiles = 2

IARA.add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_1",
)

# ## Plants

IARA.add_thermal_unit!(db;
    label = "ter_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 4.0,
        om_cost = 10.0,
    ),
    biddinggroup_id = "bg_2",
    has_commitment = 0,
    bus_id = "bus_1",
)

IARA.add_thermal_unit!(db;
    label = "ter_4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 4.0,
        om_cost = 20.0,
    ),
    biddinggroup_id = "bg_2",
    has_commitment = 0,
    bus_id = "bus_2",
)

number_of_bidding_groups = 2

quantity_bid_new = zeros(
    number_of_bidding_groups,
    maximum_number_of_bidding_profiles,
    number_of_buses,
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)
quantity_bid_new[1, :, :, :, :, :] .= quantity_bid[1, :, :, :, :, :]

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_bid"),
    quantity_bid_new;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "MWh",
)

price_bid_new = zeros(
    number_of_bidding_groups,
    number_of_buses,
    maximum_number_of_bidding_segments,
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)

# Choose the first subperiod of price bids for the new bidding group
price_bid_new[1, :, :, :, :, :] .= price_bid[1, :, :, :, :, :]

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_bid"),
    price_bid_new;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

# Quantity and price bids for profile bids
quantity_bid_profile =
    zeros(
        number_of_bidding_groups,
        maximum_number_of_bidding_profiles,
        number_of_buses,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
quantity_bid_profile[2, :, :, :, :, :] .= 4
IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_bid_profile"),
    quantity_bid_profile;
    dimensions = ["period", "scenario", "subperiod", "profile"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "MWh",
)

price_bid_profile = zeros(
    number_of_bidding_groups,
    maximum_number_of_bidding_profiles,
    number_of_scenarios,
    number_of_periods,
)
price_bid_profile[2, 1, :, :] .= 90 / 2
price_bid_profile[2, 2, :, :] .= 70 / 2

IARA.add_demand_unit!(db;
    label = "dem_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
    ),
    bus_id = "bus_2",
    max_demand = max_demand,
)

demand = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods) .+ 1 / max_demand
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1", "dem_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.write_timeseries_file(
    joinpath(PATH, "price_bid_profile"),
    price_bid_profile;
    dimensions = ["period", "scenario", "profile"],
    labels = ["bg_1", "bg_2"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_bid_profile = "quantity_bid_profile",
    price_bid_profile = "price_bid_profile",
)

IARA.close_study!(db)
