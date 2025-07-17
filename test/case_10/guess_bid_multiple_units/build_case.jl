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
number_of_periods = 2
number_of_subperiods = 1
number_of_scenarios = 4
subperiod_duration_in_hours = [24.0]
yearly_discount_rate = 0.1

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
    subperiod_duration_in_hours = subperiod_duration_in_hours,
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    bid_data_processing = IARA.Configurations_BiddingGroupBidProcessing.HEURISTIC_UNVALIDATED_BID,
    cycle_discount_rate = 0.0,
    cycle_duration_in_hours = 8760.0,
    demand_deficit_cost = 3000.0,
    hydro_spillage_cost = 1.0,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    settlement_type = IARA.Configurations_FinancialSettlementType.TWO_SETTLEMENT,
)

# Add collection elements
# -----------------------
IARA.add_bus!(db; label = "Island")
IARA.add_zone!(db; label = "Island Zone")

IARA.update_bus_relation!(
    db,
    "Island";
    collection = "Zone",
    relation_type = "id",
    related_label = "Island Zone",
)

IARA.add_asset_owner!(
    db;
    label = "Thermal Owner",
    price_type = IARA.AssetOwner_PriceType.PRICE_MAKER,
)
IARA.add_asset_owner!(
    db;
    label = "Price Taker",
    price_type = IARA.AssetOwner_PriceType.PRICE_TAKER,
)

IARA.add_bidding_group!(
    db;
    label = "Thermal Owner",
    assetowner_id = "Thermal Owner",
    risk_factor = [0.5],
    segment_fraction = [1.0],
)
IARA.add_bidding_group!(
    db;
    label = "Price Taker",
    assetowner_id = "Price Taker",
    risk_factor = [0.5],
    segment_fraction = [1.0],
)

IARA.add_demand_unit!(db;
    label = "Demand1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Island",
    max_demand = 1.8 * 1000 / subperiod_duration_in_hours[1],
)

IARA.add_demand_unit!(db;
    label = "Demand2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Island",
    max_demand = 0.72 * 1000 / subperiod_duration_in_hours[1],
)

IARA.add_demand_unit!(db;
    label = "Demand3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
    ),
    bus_id = "Island",
    max_demand = 0.36 * 1000 / subperiod_duration_in_hours[1],
)

IARA.add_renewable_unit!(
    db;
    label = "Solar1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [80.0],
        om_cost = [0.0],
        curtailment_cost = [100.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [10.0],
    ),
    biddinggroup_id = "Thermal Owner",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [30.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [100.0],
    ),
    biddinggroup_id = "Thermal Owner",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal4",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [20.0],
        om_cost = [300.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal5",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [50.0],
        om_cost = [1000.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

IARA.add_thermal_unit!(
    db;
    label = "Thermal6",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [1],
        max_generation = [50.0],
        om_cost = [3000.0],
    ),
    biddinggroup_id = "Price Taker",
    bus_id = "Island",
)

IARA.link_time_series_to_file(
    db,
    "RenewableUnit";
    generation_ex_ante = "solar_generation",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demands",
)

demand = ones(3, 1, 4, 2)
demand[1, :, :, :] = [0.86656, 0.6, 0.6, 0.86656, 1.0, 0.73344, 0.73344, 1.0]

IARA.write_timeseries_file(
    joinpath(PATH, "demands"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["Demand1", "Demand2", "Demand3"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

renw_generation = [
    0.250008
    0.124992
    0.250008
    0.124992
    0.375
    0.250008
    0.375
    0.250008
]
renw_generation = reshape(renw_generation, (1, 1, 4, 2))

IARA.write_timeseries_file(
    joinpath(PATH, "solar_generation"),
    renw_generation;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["Solar1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.close_study!(db)
