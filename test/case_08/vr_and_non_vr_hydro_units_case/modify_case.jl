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

# Bids equivalent to the old heuristic bid

number_of_vr_segments = 2
vr_quantity_offer = zeros(
    1,
    2,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)

vr_price_offer = zeros(
    1,
    2,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)

quantity_data = [
    (1, 1, 1, 1.7, 6.8),
    (1, 1, 2, 1.12, 4.48),
    (1, 2, 1, 1.7, 6.8),
    (1, 2, 2, 1.18, 4.72),
    (2, 1, 1, 1.18, 4.72),
    (2, 1, 2, 0.62, 2.48),
    (2, 2, 1, 1.34, 5.36),
    (2, 2, 2, 0.7, 2.8),
    (3, 1, 1, 0.24, 0.96),
    (3, 1, 2, 0.81, 3.24),
    (3, 2, 1, 0.44, 1.76),
    (3, 2, 2, 1.02, 4.08),
]

price_data = [
    (1, 1, 1, 122.800003, 122.800003),
    (1, 1, 2, 122.800003, 122.800003),
    (1, 2, 1, 0.01, 0.01),
    (1, 2, 2, 0.01, 0.01),
    (2, 1, 1, 245.600006, 245.600006),
    (2, 1, 2, 245.600006, 245.600006),
    (2, 2, 1, 0.01, 0.01),
    (2, 2, 2, 0.01, 0.01),
    (3, 1, 1, 491.200012, 491.200012),
    (3, 1, 2, 491.200012, 491.200012),
    (3, 2, 1, 0.01, 0.01),
    (3, 2, 2, 0.01, 0.01),
]

for entry in quantity_data
    period, scenario, bid_segment, virtual_reservoir_1, virtual_reservoir_2 = entry
    vr_quantity_offer[1, 1, bid_segment, scenario, period] = virtual_reservoir_1
    vr_quantity_offer[1, 2, bid_segment, scenario, period] = virtual_reservoir_2
end

for entry in price_data
    period, scenario, bid_segment, virtual_reservoir_1, virtual_reservoir_2 = entry
    vr_price_offer[1, 1, bid_segment, scenario, period] = virtual_reservoir_1
    vr_price_offer[1, 2, bid_segment, scenario, period] = virtual_reservoir_2
end

map = Dict(
    "virtual_reservoir_1" => ["asset_owner_1", "asset_owner_2"],
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "vr_quantity_offer"),
    vr_quantity_offer;
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
    joinpath(PATH, "vr_price_offer"),
    vr_price_offer;
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
    quantity_offer = "vr_quantity_offer",
    price_offer = "vr_price_offer",
)

quantity_offer =
    zeros(
        1,
        1,
        1,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )

price_offer =
    zeros(
        1,
        1,
        1,
        number_of_subperiods,
        number_of_scenarios,
        number_of_periods,
    )

quantity_data = [
    (1, 1, 1, 1, 0.9)
    (1, 1, 2, 1, 0.0)
    (1, 1, 3, 1, 0.0)
    (1, 2, 1, 1, 0.6)
    (1, 2, 2, 1, 0.0)
    (1, 2, 3, 1, 0.0)
    (2, 1, 1, 1, 0.6)
    (2, 1, 2, 1, 0.6)
    (2, 1, 3, 1, 0.6)
    (2, 2, 1, 1, 0.84375)
    (2, 2, 2, 1, 0.84375)
    (2, 2, 3, 1, 1.0125)
    (3, 1, 1, 1, 0.6)
    (3, 1, 2, 1, 0.6)
    (3, 1, 3, 1, 0.6)
    (3, 2, 1, 1, 0.84375)
    (3, 2, 2, 1, 0.73125)
    (3, 2, 3, 1, 1.125)
]

price_data = [
    (1, 1, 1, 1, 122.800003)
    (1, 1, 2, 1, 122.800003)
    (1, 1, 3, 1, 122.800003)
]

for entry in quantity_data
    period, scenario, subperiod, bid_segment, bidding_group_1 = entry
    quantity_offer[1, 1, bid_segment, subperiod, scenario, period] = bidding_group_1
end

for entry in price_data
    period, scenario, subperiod, bid_segment, bidding_group_1 = entry
    price_offer[1, 1, bid_segment, subperiod, scenario, period] = bidding_group_1
end

IARA.write_bids_time_series_file(
    joinpath(PATH, "quantity_offer"),
    quantity_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bidding_group_1"],
    labels_buses = ["bus_1"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        1,
    ],
    initial_date = "2024-01-01",
    unit = "MWh",
)

IARA.write_bids_time_series_file(
    joinpath(PATH, "price_offer"),
    price_offer;
    dimensions = ["period", "scenario", "subperiod", "bid_segment"],
    labels_bidding_groups = ["bidding_group_1"],
    labels_buses = ["bus_1"],
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_subperiods,
        1,
    ],
    initial_date = "2024-01-01",
    unit = "\$/MWh",
)
IARA.link_time_series_to_file(
    db,
    "BiddingGroup";
    quantity_offer = "quantity_offer",
    price_offer = "price_offer",
)

IARA.close_study!(db)
