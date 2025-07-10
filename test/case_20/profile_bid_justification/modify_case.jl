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

# Remove BG "Verde" from independent bids
quantity_offer_new = copy(quantity_offer)
quantity_offer_new[3, :, :, :, :, :] .= 0
IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer_new;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Azul", "Vermelho", "Verde"],
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

price_offer_new = copy(price_offer)
price_offer_new[3, :, :, :, :, :] .= 0.0
IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer_new;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Azul", "Vermelho", "Verde"],
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

# Build profile bids
maximum_number_of_bidding_profiles = 2

quantity_offer_profile = zeros(
    number_of_bidding_groups,
    number_of_buses,
    maximum_number_of_bidding_profiles,
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)
quantity_offer_profile[3, :, :, :, :, :] .= 60
IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer_profile"),
    quantity_offer_profile;
    dimensions = ["period", "scenario", "subperiod", "profile"],
    labels_bidding_groups = ["Azul", "Vermelho", "Verde"],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "MW",
)

price_offer_profile = zeros(
    number_of_bidding_groups,
    maximum_number_of_bidding_profiles,
    number_of_scenarios,
    number_of_periods,
)
price_offer_profile[3, :, :, 1:3] .= 8.0
price_offer_profile[3, :, :, 4:6] .= 10.0
price_offer_profile[3, :, :, 7:10] .= 12.0
IARA.write_timeseries_file(
    joinpath(PATH, "price_offer_profile"),
    price_offer_profile;
    dimensions = ["period", "scenario", "profile"],
    labels = ["Azul", "Vermelho", "Verde"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        maximum_number_of_bidding_profiles,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)

# Build bid price limit files
bid_price_limit_justified_profile =
    zeros(number_of_bidding_groups, number_of_periods)
bid_price_limit_non_justified_profile =
    zeros(number_of_bidding_groups, number_of_periods)

IARA.write_timeseries_file(
    joinpath(PATH, "bid_price_limit_justified_profile"),
    bid_price_limit_justified_profile;
    dimensions = ["period"],
    labels = ["Azul", "Vermelho", "Verde"],
    time_dimension = "period",
    dimension_size = [number_of_periods],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)
IARA.write_timeseries_file(
    joinpath(PATH, "bid_price_limit_non_justified_profile"),
    bid_price_limit_non_justified_profile;
    dimensions = ["period"],
    labels = ["Azul", "Vermelho", "Verde"],
    time_dimension = "period",
    dimension_size = [number_of_periods],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)

# Link timeseries
IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer_profile = "quantity_offer_profile",
    price_offer_profile = "price_offer_profile",
    bid_price_limit_justified_profile = "bid_price_limit_justified_profile",
    bid_price_limit_non_justified_profile = "bid_price_limit_non_justified_profile",
)

IARA.close_study!(db)
