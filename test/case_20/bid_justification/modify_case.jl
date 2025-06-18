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

# Modify database
IARA.update_bidding_group!(
    db,
    "Azul";
    bid_price_limit_source = IARA.BiddingGroup_BidPriceLimitSource.READ_FROM_FILE,
)

# Modify timeseries
# Azul
price_offer[1, :, 2, :, :, 1:3] .= 15.0
price_offer[1, :, 2, :, :, 4:6] .= 25.0
price_offer[1, :, 2, :, :, 7:10] .= 35.0
# Verde
price_offer[3, :, 2, :, :, 1:5] .= 10.0
price_offer[3, :, 2, :, :, 6:10] .= 15.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer;
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

# Build bid justifications file
justifications = []
for period in 1:number_of_periods
    period_justification = Dict(
        "period" => period,
        "justifications" => Dict(
            "Azul" => "foo bar baz",
        ),
    )
    push!(justifications, period_justification)
end

open(joinpath(PATH, "bid_justifications.json"), "w") do file
    return write(file, IARA.JSON.json(justifications))
end

# Build bid price limit files
bid_price_limit_justified_independent =
    zeros(number_of_bidding_groups, number_of_periods)
bid_price_limit_justified_independent[1, :] .= 30.0

bid_price_limit_non_justified_independent =
    zeros(number_of_bidding_groups, number_of_periods)
bid_price_limit_non_justified_independent[1, :] .= 20.0

IARA.write_timeseries_file(
    joinpath(PATH, "bid_price_limit_justified_independent"),
    bid_price_limit_justified_independent;
    dimensions = ["period"],
    labels = ["Azul", "Vermelho", "Verde"],
    time_dimension = "period",
    dimension_size = [number_of_periods],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.write_timeseries_file(
    joinpath(PATH, "bid_price_limit_non_justified_independent"),
    bid_price_limit_non_justified_independent;
    dimensions = ["period"],
    labels = ["Azul", "Vermelho", "Verde"],
    time_dimension = "period",
    dimension_size = [number_of_periods],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)

# Link files
IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    bid_justifications = "bid_justifications.json",
    bid_price_limit_justified_independent = "bid_price_limit_justified_independent",
    bid_price_limit_non_justified_independent = "bid_price_limit_non_justified_independent",
)

IARA.close_study!(db)
