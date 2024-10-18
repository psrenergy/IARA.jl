#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = load_study(PATH; read_only = false)

maximum_number_of_bidding_profiles = 2

add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_1",
    multihour_bid_max_profiles = 2,
)

# ## Plants

add_thermal_plant!(db;
    label = "ter_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        min_generation = 0.0,
        max_generation = 4.0,
        om_cost = 10.0,
    ),
    biddinggroup_id = "bg_2",
    has_commitment = 0,
    bus_id = "bus_1",
)

add_thermal_plant!(db;
    label = "ter_4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        min_generation = 0.0,
        max_generation = 4.0,
        om_cost = 20.0,
    ),
    biddinggroup_id = "bg_2",
    has_commitment = 0,
    bus_id = "bus_2",
)

number_of_bidding_groups = 2

quantity_offer_new = zeros(
    number_of_bidding_groups,
    maximum_number_of_bidding_profiles,
    number_of_buses,
    number_of_blocks,
    number_of_scenarios,
    number_of_stages,
)
quantity_offer_new[1, :, :, :, :, :] .= quantity_offer[1, :, :, :, :, :]

write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer_new;
    dimensions = ["stage", "scenario", "block", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "stage",
    dimension_size = [
        number_of_stages,
        number_of_scenarios,
        number_of_blocks,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "MWh",
)

price_offer_new = zeros(
    number_of_bidding_groups,
    number_of_buses,
    maximum_number_of_bidding_segments,
    number_of_blocks,
    number_of_scenarios,
    number_of_stages,
)

# Choose the first block of price offers for the new bidding group
price_offer_new[1, :, :, :, :, :] .= price_offer[1, :, :, :, :, :]

write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer_new;
    dimensions = ["stage", "scenario", "block", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "stage",
    dimension_size = [
        number_of_stages,
        number_of_scenarios,
        number_of_blocks,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

# Quantity and price offers for multihour bids
quantity_offer_multihour =
    zeros(
        number_of_bidding_groups,
        maximum_number_of_bidding_profiles,
        number_of_buses,
        number_of_blocks,
        number_of_scenarios,
        number_of_stages,
    )
quantity_offer_multihour[2, :, :, :, :, :] .= 4
write_bids_time_series_file(
    joinpath(PATH, "quantity_offer_multihour"),
    quantity_offer_multihour;
    dimensions = ["stage", "scenario", "block", "profile"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1", "bus_2"],
    time_dimension = "stage",
    dimension_size = [
        number_of_stages,
        number_of_scenarios,
        number_of_blocks,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "MWh",
)

price_offer_multihour = zeros(
    number_of_bidding_groups,
    maximum_number_of_bidding_profiles,
    number_of_scenarios,
    number_of_stages,
)
price_offer_multihour[2, 1, :, :] .= 90 / 2
price_offer_multihour[2, 2, :, :] .= 70 / 2

add_demand!(db;
    label = "dem_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "bus_2",
)

demand = zeros(2, number_of_blocks, number_of_scenarios, number_of_stages) .+ 1 * MW_to_GWh
write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_1", "dem_2"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

write_timeseries_file(
    joinpath(PATH, "price_offer_multihour"),
    price_offer_multihour;
    dimensions = ["stage", "scenario", "profile"],
    labels = ["bg_1", "bg_2"],
    time_dimension = "stage",
    dimension_size = [
        number_of_stages,
        number_of_scenarios,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer_multihour = "quantity_offer_multihour",
    price_offer_multihour = "price_offer_multihour",
)

close_study!(db)
