db = IARA.load_study(PATH; read_only = false)

IARA.add_bidding_group!(db;
    label = "bidding_group_1",
    assetowner_id = "asset_owner_1",
    segment_fraction = [1.0],
    risk_factor = [0.0],
)

IARA.add_hydro_unit!(db;
    label = "hydro_3",
    initial_volume = 5.0 * m3_per_second_to_hm3,
    bus_id = "bus_1",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1.5,
        max_generation = 2.0,
        max_turbining = 2.0,
        min_volume = 0.0,
        max_volume = 15.0 * m3_per_second_to_hm3,
        om_cost = 0.11,
    ),
    biddinggroup_id = "bidding_group_1",
)

inflow = [0.2 + 0.2s for h in 1:3, b in 1:number_of_subperiods, s in 1:number_of_scenarios, t in 1:number_of_periods]
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hydro_1", "hydro_2", "hydro_3"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "m3/s",
)
IARA.link_time_series_to_file(db, "HydroUnit"; inflow_ex_ante = "inflow")

hydro_opportunity_cost = zeros(3, number_of_subperiods, number_of_scenarios, number_of_periods)
hydro_opportunity_cost[:, :, 1, 1] .= 122.8
hydro_opportunity_cost[1:2, :, 2, :] .= 0.01
hydro_opportunity_cost[1:2, :, 1, 2] .= 245.6
hydro_opportunity_cost[1:2, :, 1, 3] .= 491.2

IARA.write_timeseries_file(
    joinpath(PATH, "hydro_opportunity_cost"),
    hydro_opportunity_cost;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hydro_1", "hydro_2", "hydro_3"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "\$/MWh",
)

hydro_generation = zeros(3, number_of_subperiods, number_of_scenarios, number_of_periods)
hydro_generation[:, :, 1, 1] = [
    3.5 1.5 3.5
    0.6 3.5 1.5
    0.9 0.0 0.0
]

hydro_generation[:, :, 2, 1] = [
    3.5 1.5 3.5
    0.9 3.5 1.5
    0.6 0.0 0.0
]

hydro_generation[:, :, 1, 2] = [
    3.0 0.0 2.9
    0.0 3.0 0.1
    2.0 2.0 2.0
]

hydro_generation[:, :, 2, 2] = [
    3.5 0.0 3.2
    0.0 3.5 0.0
    1.5 1.5 1.8
]

hydro_generation[:, :, 1, 3] = [
    0.0 0.0 1.2
    3.0 2.1 2.0
    2.0 2.0 2.0
]

hydro_generation[:, :, 2, 3] = [
    0.0 0.2 2.0
    3.5 3.5 1.0
    1.5 1.3 2.0
]

IARA.write_timeseries_file(
    joinpath(PATH, "hydro_generation"),
    hydro_generation * MW_to_GWh;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["hydro_1", "hydro_2", "hydro_3"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2024-01-01",
    unit = "GWh",
)


