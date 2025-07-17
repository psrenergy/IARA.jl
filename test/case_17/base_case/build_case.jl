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
number_of_subperiods = 4
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
    bid_data_processing = IARA.Configurations_BiddingGroupBidProcessing.HEURISTIC_UNVALIDATED_BID,
    cycle_discount_rate = 0.0,
    cycle_duration_in_hours = 8760.0,
    demand_deficit_cost = 500.0,
    hydro_spillage_cost = 1.0,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    settlement_type = IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")
IARA.add_bus!(db; label = "bus_2", zone_id = "zone_1")

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
    bus_id = "bus_2",
)

IARA.add_hydro_unit!(db;
    label = "hyd_1",
    operation_type = IARA.HydroUnit_OperationTypeBetweenPeriods.RUN_OF_RIVER,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.HydroUnit_Existence.EXISTS)],
        production_factor = [1.0],
        min_generation = [0.0],
        max_generation = [3.5],
        max_turbining = [3.5],
        min_volume = [0.0],
        max_volume = [30.0 * m3_per_second_to_hm3],
        min_outflow = [0.0],
        om_cost = [0.0],
    ),
    initial_volume = 12.0 * m3_per_second_to_hm3,
    bus_id = "bus_2",
)

IARA.add_thermal_unit!(db;
    label = "ter_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 1.0,
        om_cost = 1.0,
    ),
    has_commitment = 0,
    bus_id = "bus_2",
)

IARA.add_thermal_unit!(db;
    label = "ter_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        min_generation = 0.0,
        max_generation = 4.6,
        om_cost = 5.0,
    ),
    has_commitment = 0,
    bus_id = "bus_1",
)

IARA.add_dc_line!(db;
    label = "dc_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.DCLine_Existence.EXISTS)],
        capacity_to = [5.5],
        capacity_from = [5.5],
    ),
    bus_from = "bus_1",
    bus_to = "bus_2",
)

max_demand = 10.0

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
    inflow[:, :, scen, :] .+= (scen - 1) * 1.5
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
    risk_factor = [0.1],
    segment_fraction = [1.0],
)
IARA.add_bidding_group!(db;
    label = "bg_2",
    assetowner_id = "asset_owner_2",
    risk_factor = [0.2, 0.3],
    segment_fraction = [0.4, 0.6],
)

IARA.update_hydro_unit_relation!(db, "hyd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_1",
)
IARA.update_thermal_unit_relation!(db, "ter_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_2",
)
IARA.update_thermal_unit_relation!(db, "ter_2";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_2",
)
IARA.update_renewable_unit_relation!(db, "gnd_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bg_2",
)

# Create CSV files
# ----------------
# We need to create this file manually instead of copying it from 
# a CENTRALIZED_OPERATION problem because marginal cost outputs are degenerate
hydro_opportunity_cost = [
    500.0;
    500.0;
    500.0;
    500.0;
    5.0;
    5.0;
    5.0;
    5.0;
    1.0;
    1.0;
    1.0;
    1.0;
    -0.0036;
    -0.0036;
    -0.0036;
    -0.0036;
    500.0;
    500.0;
    500.0;
    500.0;
    5.0;
    5.0;
    5.0;
    5.0;
    1.0;
    1.0;
    1.0;
    1.0;
    -0.0036;
    -0.0036;
    -0.0036;
    -0.0036;
    500.0;
    500.0;
    500.0;
    500.0;
    5.0;
    5.0;
    5.0;
    5.0;
    1.0;
    1.0;
    1.0;
    1.0;
    -0.0036;
    -0.0036;
    -0.0036;
    -0.0036
]
hydro_opportunity_cost =
    reshape(hydro_opportunity_cost, (1, number_of_subperiods, number_of_scenarios, number_of_periods))
IARA.write_timeseries_file(
    joinpath(PATH, "hydro_opportunity_cost"),
    hydro_opportunity_cost;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hyd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "\$/MWh",
)

hydro_generation = [
    0.0;
    0.0;
    0.0;
    0.0;
    0.0015;
    0.0015;
    0.0015;
    0.0015;
    0.003;
    0.0025;
    0.0035;
    0.003;
    0.0035;
    0.0035;
    0.0035;
    0.0035;
    0.0;
    0.0;
    0.0;
    0.0;
    0.0015;
    0.0015;
    0.0015;
    0.0015;
    0.0035;
    0.003;
    0.003;
    0.0025;
    0.0035;
    0.0035;
    0.0035;
    0.0035;
    0.0;
    0.0;
    0.0;
    0.0;
    0.0015;
    0.0015;
    0.0015;
    0.0015;
    0.003;
    0.003;
    0.003;
    0.003;
    0.0035;
    0.0035;
    0.0035;
    0.0035
]
hydro_generation = reshape(hydro_generation, (1, number_of_subperiods, number_of_scenarios, number_of_periods))
IARA.write_timeseries_file(
    joinpath(PATH, "hydro_generation"),
    hydro_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hyd_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

IARA.close_study!(db)
