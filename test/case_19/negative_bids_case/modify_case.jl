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

# Redo the VR bids from base case, but with an extra segment

number_of_virtual_reservoirs = 2
number_of_asset_owners = 2
number_of_vr_segments = 3

vr_quantity_bid = zeros(
    number_of_virtual_reservoirs,
    number_of_asset_owners,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)
vr_price_bid = zeros(
    number_of_virtual_reservoirs,
    number_of_asset_owners,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)

# VR 1, AO 1
vr_quantity_bid[1, 1, 1, :, :] .= 420.0
vr_quantity_bid[1, 1, 2, :, :] .= 70.0
vr_price_bid[1, 1, 1, :, :] .= 30.0
vr_price_bid[1, 1, 2, :, :] .= 160.0

# VR 2, AO 1
vr_quantity_bid[2, 1, 1, :, :] .= 300.0
vr_quantity_bid[2, 1, 2, :, :] .= 50.0
vr_price_bid[2, 1, 1, :, :] .= 30.0
vr_price_bid[2, 1, 2, :, :] .= 160.0

# VR 1, AO 2
vr_quantity_bid[1, 2, 1, :, :] .= 210.0
vr_price_bid[1, 2, 1, :, :] .= 90.0

# VR 2, AO 2 
vr_quantity_bid[2, 2, 1, :, :] .= 100.0
vr_quantity_bid[2, 2, 2, :, :] .= 100.0
vr_price_bid[2, 2, 1, :, :] .= 60.0
vr_price_bid[2, 2, 2, :, :] .= 110.0

# Extra segment with negative bids
# VR 1, AO 1, period 5
vr_quantity_bid[1, 1, 3, :, 5] .= -10.0
vr_price_bid[1, 1, 3, :, 5] .= 40.0
# VR 2, AO 1, period 5
vr_quantity_bid[2, 1, 3, :, 5] .= -5.0
vr_price_bid[2, 1, 3, :, 5] .= 35.0

map = Dict(
    "VR 1" => ["AO 1", "AO 2"],
    "VR 2" => ["AO 1", "AO 2"],
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "vr_quantity_bid"),
    vr_quantity_bid;
    dimensions = ["period", "scenario", "bid_segment"],
    labels_virtual_reservoirs = ["VR 1", "VR 2"],
    labels_asset_owners = ["AO 1", "AO 2"],
    virtual_reservoirs_to_asset_owners_map = map,
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_vr_segments,
    ],
    initial_date = "2024-01-01",
    unit = "MWh",
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "vr_price_bid"),
    vr_price_bid;
    dimensions = ["period", "scenario", "bid_segment"],
    labels_virtual_reservoirs = ["VR 1", "VR 2"],
    labels_asset_owners = ["AO 1", "AO 2"],
    virtual_reservoirs_to_asset_owners_map = map,
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_vr_segments,
    ],
    initial_date = "2024-01-01",
    unit = "\$/MWh",
)

IARA.link_time_series_to_file(
    db,
    "VirtualReservoir";
    quantity_bid = "vr_quantity_bid",
    price_bid = "vr_price_bid",
)

IARA.close_study!(db)
