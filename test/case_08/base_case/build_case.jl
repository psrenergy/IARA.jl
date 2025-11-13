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
number_of_scenarios = 2
number_of_subperiods = 3
subperiod_duration_in_hours = 1.0

# Conversion constants
# --------------------
MW_to_GWh = subperiod_duration_in_hours * 1e-3
m3_per_second_to_hm3 = (3600 / 1e6) * subperiod_duration_in_hours

# Create the database
# -------------------

db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    initial_date_time = "2024-01-01",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    demand_deficit_cost = 500.0,
    cycle_discount_rate = 0.1,
    bid_processing = IARA.Configurations_BidProcessing.READ_BIDS_FROM_FILE,
    bid_price_validation = IARA.Configurations_BidPriceValidation.DO_NOT_VALIDATE,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    virtual_reservoir_correspondence_type = IARA.Configurations_VirtualReservoirCorrespondenceType.DELTA_CORRESPONDENCE_CONSTRAINT,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    renewable_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    virtual_reservoir_residual_revenue_split_type = IARA.Configurations_VirtualReservoirResidualRevenueSplitType.BY_INFLOW_SHARES,
)

# Add collection elements
# -----------------------
IARA.add_zone!(db; label = "zone_1")
IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

IARA.add_hydro_unit!(db;
    label = "hydro_1",
    initial_volume = 12.0 * m3_per_second_to_hm3,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1.0,
        max_generation = 3.5,
        max_turbining = 3.5,
        min_volume = 0.0,
        max_volume = 30.0 * m3_per_second_to_hm3,
        om_cost = 0.1,
    ),
)

IARA.add_hydro_unit!(db;
    label = "hydro_2",
    initial_volume = 12.0 * m3_per_second_to_hm3,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1.0,
        max_generation = 3.5,
        max_turbining = 3.5,
        min_volume = 0.0,
        max_volume = 30.0 * m3_per_second_to_hm3,
        om_cost = 0.1,
    ),
)

max_demand = 5.0
IARA.add_demand_unit!(db;
    label = "demand_1",
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.DemandUnit_Existence.EXISTS),
    ),
    max_demand = max_demand,
)

IARA.add_asset_owner!(db; label = "asset_owner_1")
IARA.add_asset_owner!(db; label = "asset_owner_2")

IARA.add_virtual_reservoir!(db;
    label = "virtual_reservoir_1",
    assetowner_id = ["asset_owner_1", "asset_owner_2"],
    inflow_allocation = [0.2, 0.8],
    initial_energy_account_share = [0.2, 0.8],
    hydrounit_id = ["hydro_1", "hydro_2"],
)

demand = ones(1, number_of_subperiods, number_of_scenarios, number_of_periods)
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["demand_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "p.u.",
)
IARA.link_time_series_to_file(db, "DemandUnit"; demand_ex_ante = "demand")

inflow = [0.4 + 0.4s for h in 1:2, b in 1:number_of_subperiods, s in 1:number_of_scenarios, t in 1:number_of_periods]
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hydro_1", "hydro_2"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "m3/s",
)
IARA.link_time_series_to_file(db, "HydroUnit"; inflow_ex_ante = "inflow")

IARA.add_bidding_group!(db;
    label = "bidding_group_2",
    assetowner_id = "asset_owner_2",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)

IARA.update_hydro_unit_relation!(db,
    "hydro_1";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bidding_group_2",
)

IARA.update_hydro_unit_relation!(db,
    "hydro_2";
    collection = "BiddingGroup",
    relation_type = "id",
    related_label = "bidding_group_2",
)

# Bids equivalent to the old heuristic bid

number_of_vr_segments = 2
vr_quantity_bid = zeros(
    1,
    2,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)

vr_price_bid = zeros(
    1,
    2,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)

quantity_data = [
    (1, 1, 1, 1.5, 6.0),
    (1, 1, 2, 1.5, 6.0),
    (1, 2, 1, 1.5, 6.0),
    (1, 2, 2, 1.5, 6.0),
    (2, 1, 1, 1.5, 6.0),
    (2, 1, 2, 1.5, 6.0),
    (2, 2, 1, 1.5, 6.0),
    (2, 2, 2, 1.5, 6.0),
    (3, 1, 1, 0.84, 3.36),
    (3, 1, 2, 0.84, 3.36),
    (3, 2, 1, 0.0, 0.0),
    (3, 2, 2, 0.0, 0.0),
]

price_data = [
    (1, 1, 1, 491.198334, 491.198334),
    (1, 1, 2, 491.198334, 491.198334),
    (1, 2, 1, 368.398743, 368.398743),
    (1, 2, 2, 368.398743, 368.398743),
    (2, 1, 1, 491.198334, 491.198334),
    (2, 1, 2, 491.198334, 491.198334),
    (2, 2, 1, 245.599167, 245.599167),
    (2, 2, 2, 245.599167, 245.599167),
    (3, 1, 1, 491.198334, 491.198334),
    (3, 1, 2, 491.198334, 491.198334),
    (3, 2, 1, 0.0, 0.0),
    (3, 2, 2, 0.0, 0.0),
]

for entry in quantity_data
    period, scenario, bid_segment, virtual_reservoir_1, virtual_reservoir_2 = entry
    vr_quantity_bid[1, 1, bid_segment, scenario, period] = virtual_reservoir_1
    vr_quantity_bid[1, 2, bid_segment, scenario, period] = virtual_reservoir_2
end

for entry in price_data
    period, scenario, bid_segment, virtual_reservoir_1, virtual_reservoir_2 = entry
    vr_price_bid[1, 1, bid_segment, scenario, period] = virtual_reservoir_1
    vr_price_bid[1, 2, bid_segment, scenario, period] = virtual_reservoir_2
end

map = Dict(
    "virtual_reservoir_1" => ["asset_owner_1", "asset_owner_2"],
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "vr_quantity_bid"),
    vr_quantity_bid;
    dimensions = ["period", "scenario", "bid_segment"],
    labels_virtual_reservoirs = ["virtual_reservoir_1"],
    labels_asset_owners = ["asset_owner_1", "asset_owner_2"],
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
    labels_virtual_reservoirs = ["virtual_reservoir_1"],
    labels_asset_owners = ["asset_owner_1", "asset_owner_2"],
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
