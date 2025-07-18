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
subperiod_duration_in_hours = 1.0

# Conversion constants
# --------------------
m3_per_second_to_hm3 = (3600 / 1e6) * subperiod_duration_in_hours

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
    hydro_spillage_cost = 1.0,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    settlement_type = IARA.Configurations_FinancialSettlementType.EX_ANTE,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

IARA.add_thermal_unit!(db;
    label = "ter_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 5.0,
        om_cost = 1.0,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
)

IARA.add_renewable_unit!(db;
    label = "gnd_1",
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

max_demand = 5.0
IARA.add_demand_unit!(db;
    label = "dem_1",
    demand_unit_type = IARA.DemandUnit_DemandType.INELASTIC,
    max_shift_up_flexible_demand = 0.0,
    max_shift_down_flexible_demand = 0.0,
    curtailment_cost_flexible_demand = 0.0,
    max_curtailment_flexible_demand = 0.0,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.DemandUnit_Existence.EXISTS),
    ),
    bus_id = "bus_1",
    max_demand = max_demand,
)

# Add a elastic demand
IARA.add_demand_unit!(db;
    label = "dem_2",
    demand_unit_type = IARA.DemandUnit_DemandType.ELASTIC,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DemandUnit_Existence.EXISTS)],
    ),
    bus_id = "bus_1",
    max_demand = max_demand,
)

demand = ones(1, number_of_subperiods, number_of_scenarios, number_of_periods)

# Modify the demand timeseries to include elastic demand
new_demand = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods)
new_demand[1, :, :, :] .= demand[1, :, :, :]
new_demand[2, :, 1, :] .= 1.5 / max_demand
new_demand[2, :, 2, :] .= 1.0 / max_demand
new_demand[2, :, [3, 4], 1] .= 1.0 / max_demand

IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    new_demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1", "dem_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01",
    unit = "p.u.",
)

renewable_generation = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
for scen in 1:number_of_scenarios
    renewable_generation[:, :, scen, :] .+= (5 - scen) / 4
end
IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation"),
    renewable_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["gnd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_ante = "renewable_generation",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demand",
)

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
)

IARA.add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_2",
)

number_of_bidding_groups = 2
maximum_number_of_bidding_segments = 2

IARA.update_thermal_unit_relation!(db, "ter_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)

IARA.update_renewable_unit_relation!(db, "gnd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)

IARA.update_demand_unit_relation!(db, "dem_2";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_2",
)

number_of_buses = 1
nominal_demand = demand * max_demand
max_thermal_generation = 6.0
max_renewable_generation = 4.0

quantity_bid =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
quantity_bid[1, 1, 1, :, :, :] .= max_thermal_generation
quantity_bid[1, 1, 2, :, :, :] .= max_renewable_generation .* renewable_generation[1, :, :, :]
quantity_bid[2, 1, 1, :, :, :] = -new_demand[2, :, :, :]

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_bid"),
    quantity_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods, maximum_number_of_bidding_segments],
    initial_date = "2020-01-01",
    unit = "MWh",
)

price_bid = zeros(
    number_of_bidding_groups,
    number_of_buses,
    maximum_number_of_bidding_segments,
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)
price_bid[1, 1, 1, :, :, :] .= 100
price_bid[1, 1, 2, :, :, :] .= 10
price_bid[2, 1, 1, :, 1, :] .= 90
price_bid[2, 1, 1, :, 2, :] .= 110

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_bid"),
    price_bid;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
    labels_buses = ["bus_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods, maximum_number_of_bidding_segments],
    initial_date = "2020-01-01",
    unit = "\$/MWh",
)

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_bid = "quantity_bid",
    price_bid = "price_bid",
)
