#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

# Remove bid files if they exist
files_to_remove = [
    "price_bid.csv",
    "price_bid.toml",
    "quantity_bid.csv",
    "quantity_bid.toml",
]

for file in files_to_remove
    file_path = joinpath(@__DIR__, file)
    if isfile(file_path)
        rm(file_path)
        @info "Removed file: $file_path"
    end
end

db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    bid_data_processing = IARA.Configurations_BiddingGroupBidProcessing.HEURISTIC_UNVALIDATED_BID,
)

IARA.update_bidding_group!(
    db,
    "bg_1";
)

IARA.update_bidding_group_vectors!(
    db,
    "bg_1";
    risk_factor = [0.1],
    segment_fraction = [1.0],
)

IARA.update_bidding_group!(
    db,
    "bg_2";
)

IARA.update_bidding_group_vectors!(
    db,
    "bg_2";
    risk_factor = [0.2, 0.3],
    segment_fraction = [0.4, 0.6],
)

# Create the demand price timeseries
demand_price = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
demand_price[1, 1, :, :] .= 0.3
demand_price[1, 2, :, :] .= 1.3

IARA.write_timeseries_file(
    joinpath(PATH, "demand_price"),
    demand_price;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01",
    unit = "\$/MWh",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    elastic_demand_price = "demand_price",
)

IARA.close_study!(db)
