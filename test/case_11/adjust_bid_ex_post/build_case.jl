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
number_of_bidding_groups = 2
number_of_buses = 1
maximum_number_of_bidding_segments = 1
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
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    bid_data_source = IARA.Configurations_BidDataSource.READ_FROM_FILE,
    cycle_discount_rate = 0.0,
    cycle_duration_in_hours = 8760.0,
    demand_deficit_cost = 500.0,
    hydro_spillage_cost = 1.0,
    settlement_type = IARA.Configurations_SettlementType.DOUBLE,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

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

IARA.add_hydro_unit!(db;
    label = "hyd_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.HydroUnit_Existence.EXISTS)],
        production_factor = [1.0],
        min_generation = [0.0],
        max_generation = [3.5],
        max_turbining = [3.5],
        min_volume = [0.0],
        max_volume = [0.0],
        min_outflow = [0.0],
        om_cost = [0.0],
    ),
    initial_volume = 0.0,
    bus_id = "bus_1",
)

max_demand = 5.0

IARA.add_demand_unit!(db;
    label = "dem_1",
    demand_unit_type = IARA.DemandUnit_DemandType.INELASTIC,
    max_shift_up = 0.0,
    max_shift_down = 0.0,
    curtailment_cost = 0.0,
    max_curtailment = 0.0,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.DemandUnit_Existence.EXISTS),
    ),
    bus_id = "bus_1",
    max_demand = max_demand,
)

# Create and link CSV files
# -------------------------

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

inflow = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
for scen in 1:number_of_scenarios
    inflow[:, :, scen, :] .+= (scen - 1) / 2
end
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hyd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

demand = ones(1, number_of_subperiods, number_of_scenarios, number_of_periods)
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
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
    "HydroUnit";
    inflow_ex_ante = "inflow",
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

IARA.update_hydro_unit_relation!(db, "hyd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)

IARA.update_renewable_unit_relation!(db, "gnd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_2",
)

# Create CSV files
# ----------------
gnd_production = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
for scen in 1:number_of_scenarios
    gnd_production[:, :, scen, :] .= renewable_generation[:, :, scen, :] * 4.0 * subperiod_duration_in_hours
end
hydro_production = zeros(1, number_of_subperiods, number_of_scenarios, number_of_periods)
for scen in 1:number_of_scenarios
    hydro_production[:, :, scen, :] .= inflow[:, :, scen, :] * 1.0 * subperiod_duration_in_hours
end
quantity_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
# quantity_offer = zeros(2, number_of_subperiods, number_of_scenarios, number_of_periods)
price_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        maximum_number_of_bidding_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )
quantity_offer[2, :, :, :, :, :] = gnd_production
quantity_offer[1, :, :, :, :, :] = hydro_production
price_offer[1, :, :, :, :, :] .= 10.0
price_offer[2, :, :, :, :, :] .= 20.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bg_1", "bg_2"],
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
    labels_bidding_groups = ["bg_1", "bg_2"],
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

number_of_subscenarios = 2

# Update base case elements
IARA.update_configuration!(db;
    number_of_subscenarios,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
)

# Create and link CSV files
# -------------------------
mv(joinpath(PATH, "renewable_generation.csv"), joinpath(PATH, "renewable_generation_ex_ante.csv"); force = true)
mv(joinpath(PATH, "renewable_generation.toml"), joinpath(PATH, "renewable_generation_ex_ante.toml"); force = true)

renewable_generation_ex_post =
    zeros(1, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
renewable_generation_ex_post[:, :, 1, :, :] = renewable_generation .- 0.25
renewable_generation_ex_post[:, :, 2, :, :] = renewable_generation .+ 0.25
IARA.write_timeseries_file(
    joinpath(PATH, "renewable_generation_ex_post"),
    renewable_generation_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["gnd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_ante = "renewable_generation_ex_ante",
    generation_ex_post = "renewable_generation_ex_post",
)

IARA.close_study!(db)
