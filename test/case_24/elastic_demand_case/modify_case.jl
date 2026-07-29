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

IARA.add_asset_owner!(db; label = "Agente Demanda Elastica", purchase_discount_rate = [0.1])

IARA.add_bidding_group!(
    db;
    label = "Demanda Elastica",
    assetowner_id = "Agente Demanda Elastica",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    ex_post_adjust_mode = IARA.BiddingGroup_ExPostAdjustMode.NO_ADJUSTMENT,
)

# Add a elastic demand, 1/4 the size of the inelastic demand
IARA.add_demand_unit!(db;
    label = "Demanda Elastica",
    demand_unit_type = IARA.DemandUnit_DemandType.ELASTIC,
    max_demand = max_demand / 4,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
    ),
    bus_id = "Sistema",
    biddinggroup_id = "Demanda Elastica",
)

# Modify the demand timeseries to include elastic demand
new_demand_ex_post = vcat(demand_factor_ex_post, demand_factor_ex_post)

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    new_demand_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Demanda", "Demanda Elastica"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)

new_demand_ex_ante = vcat(demand_factor_ex_ante, demand_factor_ex_ante)

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_ante"),
    new_demand_ex_ante;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["Demanda", "Demanda Elastica"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)

# Add demand price timeseries for heuristic bids and mincost
elastic_demand_price = zeros(
    1,
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
) .+ 140.0

IARA.write_timeseries_file(
    joinpath(PATH, "elastic_demand_price"),
    elastic_demand_price;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["Demanda Elastica"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)
IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    elastic_demand_price = "elastic_demand_price",
)

# Modify bid files
new_quantity_bid =
    zeros(
        number_of_bidding_groups + 1,
        number_of_buses,
        number_of_bg_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )

new_price_bid =
    zeros(
        number_of_bidding_groups + 1,
        number_of_buses,
        number_of_bg_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )

IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_energy_bid"),
    new_quantity_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = [
        "Termico 1",
        "Termico 2",
        "Termico 3",
        "Peaker 1",
        "Peaker 2",
        "Peaker 3",
        "Demanda Elastica",
    ],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        number_of_bg_segments,
    ],
    initial_date = "2025-01-01",
    unit = "MWh",
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "bidding_group_price_bid"),
    new_price_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = [
        "Termico 1",
        "Termico 2",
        "Termico 3",
        "Peaker 1",
        "Peaker 2",
        "Peaker 3",
        "Demanda Elastica",
    ],
    labels_buses = ["Sistema"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        number_of_bg_segments,
    ],
    initial_date = "2025-01-01",
    unit = "\$/MWh",
)

IARA.close_study!(db)
