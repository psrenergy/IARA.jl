using Dates
using DataFrames

number_of_periods = 5
number_of_scenarios = 2
number_of_subscenarios = 3
number_of_subperiods = 2
subperiod_duration_in_hours = 1.0

MW_to_GWh = subperiod_duration_in_hours * 1e-3
m3_per_second_to_hm3 = (3600 / 1e6) * subperiod_duration_in_hours

db = IARA.create_study!(PATH;
    number_of_periods = number_of_periods,
    number_of_scenarios = number_of_scenarios,
    number_of_subperiods = number_of_subperiods,
    number_of_subscenarios = number_of_subscenarios,
    initial_date_time = "2024-01-01",
    subperiod_duration_in_hours = [subperiod_duration_in_hours for _ in 1:number_of_subperiods],
    policy_graph_type = IARA.Configurations_PolicyGraphType.LINEAR,
    demand_deficit_cost = 200.0,
    cycle_discount_rate = 0.0,
    clearing_hydro_representation = IARA.Configurations_ClearingHydroRepresentation.VIRTUAL_RESERVOIRS,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.HYBRID,
    settlement_type = IARA.Configurations_SettlementType.EX_POST,
    bid_data_source = IARA.Configurations_BidDataSource.READ_FROM_FILE,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
)

IARA.add_zone!(db; label = "zone_1")

IARA.add_bus!(db; label = "bus_1", zone_id = "zone_1")

IARA.add_asset_owner!(db; label = "AO 1")
IARA.add_asset_owner!(db; label = "AO 2")

IARA.add_bidding_group!(
    db;
    label = "BG 1",
    assetowner_id = "AO 1",
)

IARA.add_bidding_group!(
    db;
    label = "BG 2",
    assetowner_id = "AO 2",
)

IARA.add_thermal_unit!(
    db;
    label = "thermal",
    bus_id = "bus_1",
    biddinggroup_id = "BG 2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.ThermalUnit_Existence.EXISTS),
        max_generation = [100.0],
        om_cost = [100.0],
    ),
)

IARA.add_hydro_unit!(db;
    label = "hydro_1",
    initial_volume = 0.5,
    bus_id = "bus_1",
    biddinggroup_id = "BG 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.36,
        max_generation = 100.0,
        min_volume = 0.0,
        max_turbining = 100 / 0.36,
        max_volume = 7.0,
        om_cost = 5.0,
    ),
)

IARA.add_hydro_unit!(db;
    label = "hydro_2",
    initial_volume = 0.5,
    bus_id = "bus_1",
    biddinggroup_id = "BG 2",
    hydrounit_turbine_to = "hydro_1",
    hydrounit_spill_to = "hydro_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.36,
        max_generation = 100.0,
        min_volume = 0.0,
        max_turbining = 100 / 0.36,
        max_volume = 7.0,
        om_cost = 6.0,
    ),
)

IARA.add_hydro_unit!(db;
    label = "hydro_3",
    initial_volume = 0.5,
    bus_id = "bus_1",
    biddinggroup_id = "BG 1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.36,
        max_generation = 100.0,
        min_volume = 0.0,
        max_turbining = 100 / 0.36,
        max_volume = 7.0,
        om_cost = 7.0,
    ),
)

IARA.add_hydro_unit!(db;
    label = "hydro_4",
    initial_volume = 0.5,
    bus_id = "bus_1",
    biddinggroup_id = "BG 2",
    hydrounit_turbine_to = "hydro_3",
    hydrounit_spill_to = "hydro_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.36,
        max_generation = 100.0,
        min_volume = 0.0,
        max_turbining = 100 / 0.36,
        max_volume = 7.0,
        om_cost = 8.0,
    ),
)

IARA.add_virtual_reservoir!(db;
    label = "VR 1",
    assetowner_id = ["AO 1", "AO 2"],
    inflow_allocation = [0.7, 0.3],
    hydrounit_id = ["hydro_1", "hydro_2"],
)

IARA.add_virtual_reservoir!(db;
    label = "VR 2",
    assetowner_id = ["AO 1", "AO 2"],
    inflow_allocation = [0.5, 0.5],
    hydrounit_id = ["hydro_3", "hydro_4"],
)

IARA.add_demand_unit!(db;
    label = "demand",
    bus_id = "bus_1",
    max_demand = 400.0,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.DemandUnit_Existence.EXISTS),
    ),
)

# Time Series
inflow = zeros(4, number_of_subperiods, number_of_scenarios, number_of_periods)
inflow .= 0.5 / m3_per_second_to_hm3

IARA.write_timeseries_file(
    joinpath(PATH, "inflow_ex_ante"),
    inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hydro_1", "hydro_2", "hydro_3", "hydro_4"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "m3/s",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow_ex_ante = "inflow_ex_ante",
)

demand = zeros(1, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
demand[:, :, 1, :, :] .= 0.875
demand[:, :, 2, :, :] .= 0.75
demand[:, :, 3, :, :] .= 1.0

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    demand;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["demand"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_post = "demand_ex_post",
)

number_of_bg_segments = 1
number_of_bidding_groups = 1
number_of_buses = 1

bg_quantity_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        number_of_bg_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    ) .+ 100.0

bg_price_offer =
    zeros(
        number_of_bidding_groups,
        number_of_buses,
        number_of_bg_segments,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    ) .+ 120.0

IARA.write_bids_time_series_file(
    joinpath(PATH, "bg_quantity_offer"),
    bg_quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["BG 2"],
    labels_buses = ["bus_1"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        number_of_bg_segments,
    ],
    initial_date = "2024-01-01",
    unit = "MW",
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "bg_price_offer"),
    bg_price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["BG 2"],
    labels_buses = ["bus_1"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        number_of_bg_segments,
    ],
    initial_date = "2024-01-01",
    unit = "\$/MWh",
)

IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer = "bg_quantity_offer",
    price_offer = "bg_price_offer",
)

number_of_virtual_reservoirs = 2
number_of_asset_owners = 2
number_of_vr_segments = 2

vr_quantity_offer = zeros(
    number_of_virtual_reservoirs,
    number_of_asset_owners,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)
vr_price_offer = zeros(
    number_of_virtual_reservoirs,
    number_of_asset_owners,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)

# VR 1, AO 1
vr_quantity_offer[1, 1, 1, :, :] .= 420.0
vr_quantity_offer[1, 1, 2, :, :] .= 70.0
vr_price_offer[1, 1, 1, :, :] .= 30.0
vr_price_offer[1, 1, 2, :, :] .= 160.0

# VR 2, AO 1
vr_quantity_offer[2, 1, 1, :, :] .= 300.0
vr_quantity_offer[2, 1, 2, :, :] .= 50.0
vr_price_offer[2, 1, 1, :, :] .= 30.0
vr_price_offer[2, 1, 2, :, :] .= 160.0

# VR 1, AO 2
vr_quantity_offer[1, 2, 1, :, :] .= 210.0
vr_price_offer[1, 2, 1, :, :] .= 90.0

# VR 2, AO 2 
vr_quantity_offer[2, 2, 1, :, :] .= 100.0
vr_quantity_offer[2, 2, 2, :, :] .= 100.0
vr_price_offer[2, 2, 1, :, :] .= 60.0
vr_price_offer[2, 2, 2, :, :] .= 110.0

map = Dict(
    "VR 1" => ["AO 1", "AO 2"],
    "VR 2" => ["AO 1", "AO 2"],
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "vr_quantity_offer"),
    vr_quantity_offer;
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
    unit = "MW",
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "vr_price_offer"),
    vr_price_offer;
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
    quantity_offer = "vr_quantity_offer",
    price_offer = "vr_price_offer",
)

IARA.close_study!(db)
