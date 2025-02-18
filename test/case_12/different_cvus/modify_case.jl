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

# modify thermal units

IARA.update_thermal_unit_time_series_parameter!(
    db,
    "Thermal 1",
    "om_cost",
    40;
    date_time = DateTime(0)
)

IARA.update_thermal_unit_time_series_parameter!(
    db,
    "Thermal 2",
    "om_cost",
    50;
    date_time = DateTime(0)
)

IARA.update_thermal_unit_time_series_parameter!(
    db,
    "Thermal 3",
    "om_cost",
    65;
    date_time = DateTime(0)
)

number_of_buses = 1
number_of_bidding_groups = 3
maximum_number_of_bidding_segments = 1
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

quantity_offer[1, :, :, :, :, :] .= 100
quantity_offer[2, :, :, :, :, :] .= 100
quantity_offer[3, :, :, :, :, :] .= 100
price_offer[1, :, :, :, :, :] .= 41.0
price_offer[2, :, :, :, :, :] .= 51.0
price_offer[3, :, :, :, :, :] .= 65.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Bidding Group 1", "Bidding Group 2", "Bidding Group 3"],
    labels_buses = ["Bus 1"],
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
    joinpath(PATH, "price_offer"),
    price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["Bidding Group 1", "Bidding Group 2", "Bidding Group 3"],
    labels_buses = ["Bus 1"],
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
    quantity_offer = "quantity_offer",
    price_offer = "price_offer",
)
