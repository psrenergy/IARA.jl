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

number_of_bidding_groups = 3

IARA.add_bidding_group!(db;
    label = "bg_3",
    assetowner_id = "asset_owner_1",  # or re-use an existing asset owner if preferred
    bid_type = IARA.BiddingGroup_BidType.OPTIMIZE,
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NONE,
)

# Add an extra renewable unit "gnd_2"
IARA.add_renewable_unit!(db;
    label = "gnd_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [4.0],
        om_cost = [0.0],
        curtailment_cost = [0.1],
    ),
    technology_type = 1,
    bus_id = "bus_1",
)

# Link the new renewable unit "gnd_2" to bidding group "bg_1"
IARA.update_renewable_unit_relation!(db, "gnd_2";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_3",
)

IARA.update_demand_unit!(db, "dem_1";
    max_demand = 10.0,
)

# Ex ante generation for 2 renewables:
renewable_generation = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods)

for r in 1:2
    for scen in 1:number_of_scenarios
        renewable_generation[r, :, scen, :] .= (5 - scen) / 4
    end
end

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation_ex_ante"),
    renewable_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["gnd_1", "gnd_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

# Ex post generation for 2 renewables:
# Create an array with an extra subscenario dimension, e.g., two subscenarios per scenario.
renewable_generation_ex_post =
    zeros(2, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
for r in 1:2
    for scen in 1:number_of_scenarios
        # For subscenario 1, subtract 0.25 from the ex ante values:
        renewable_generation_ex_post[r, :, 1, scen, :] = renewable_generation[r, :, scen, :] .- 0.25
        # For subscenario 2, add 0.25 to the ex ante values:
        renewable_generation_ex_post[r, :, 2, scen, :] = renewable_generation[r, :, scen, :] .+ 0.25
    end
end

IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation_ex_post"),
    renewable_generation_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["gnd_1", "gnd_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

# Update bids time series arrays dimensions:
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

# For example, if you assign production as before:
# Assume bidding group 1 gets hydro production, group 2 gets gnd_production,
# and for demonstration, let group 3 use the same renewable production as group 2 
# (adjust as needed).

quantity_offer[1, :, :, :, :, :] = hydro_production
quantity_offer[2, :, :, :, :, :] = gnd_production
quantity_offer[3, :, :, :, :, :] = gnd_production  # assignment for bg_3

price_offer[1, :, :, :, :, :] .= 10.0
price_offer[2, :, :, :, :, :] .= 20.0
price_offer[3, :, :, :, :, :] .= 25.0  # pricing for bg_3

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2", "bg_3"],
    labels_buses = ["bus_1"],
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

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2", "bg_3"],
    labels_buses = ["bus_1"],
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

# Finally, update the renewable unit link to the new files:
IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_ante = "renewable_generation_ex_ante",
    generation_ex_post = "renewable_generation_ex_post",
)

IARA.close_study!(db)
