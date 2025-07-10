db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    virtual_reservoir_initial_energy_account_share = IARA.Configurations_VirtualReservoirInitialEnergyAccount.CALCULATED_USING_ENERGY_ACCOUNT_SHARES,
)

IARA.PSRDatabaseSQLite.update_vector_parameters!(
    db,
    "VirtualReservoir",
    "initial_energy_account_share",
    "virtual_reservoir_1",
    [0.3, 0.7],
)

virtual_reservoir_quantity_offer = zeros(
    1, # number of virtual reservoirs
    2, # number of asset owners
    2, # number of segments
    number_of_scenarios,
    number_of_periods,
)

virtual_reservoir_price_offer = zeros(
    1, # number of virtual reservoirs
    2, # number of asset owners
    2, # number of segments
    number_of_scenarios,
    number_of_periods,
)

quantity_data = [
    (1, 1, 1, 2.55, 5.95),
    (1, 1, 2, 1.68, 3.92),
    (1, 2, 1, 2.55, 5.95),
    (1, 2, 2, 1.77, 4.13),
    (2, 1, 1, 1.654878, 4.245122),
    (2, 1, 2, 0.869512, 2.230488),
    (2, 2, 1, 1.827273, 4.872727),
    (2, 2, 2, 0.954546, 2.545455),
    (3, 1, 1, 0.295918, 0.904082),
    (3, 1, 2, 0.998723, 3.051277),
    (3, 2, 1, 0.512727, 1.687273),
    (3, 2, 2, 1.188595, 3.911405),
]

for entry in quantity_data
    period, scenario, bid_segment, quantity_asset_owner_1, quantity_asset_owner_2 = entry
    virtual_reservoir_quantity_offer[1, 1, bid_segment, scenario, period] = quantity_asset_owner_1
    virtual_reservoir_quantity_offer[1, 2, bid_segment, scenario, period] = quantity_asset_owner_2
end

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

for entry in price_data
    period, scenario, bid_segment, price_asset_owner_1, price_asset_owner_2 = entry
    virtual_reservoir_price_offer[1, 1, bid_segment, scenario, period] = price_asset_owner_1
    virtual_reservoir_price_offer[1, 2, bid_segment, scenario, period] = price_asset_owner_2
end

map = Dict(
    "virtual_reservoir_1" => ["asset_owner_1", "asset_owner_2"],
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "vr_quantity_offer"),
    virtual_reservoir_quantity_offer;
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
    virtual_reservoir_price_offer;
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

bidding_group_quantity_offer = zeros(
    1, # number of bidding groups
    1, # number of buses
    1, # number of segments
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)

bidding_group_price_offer = zeros(
    1, # number of bidding groups
    1, # number of buses
    1, # number of segments
    number_of_subperiods,
    number_of_scenarios,
    number_of_periods,
)

quantity_data = [
    (1, 1, 1, 1, 0.9),
    (1, 1, 2, 1, 0.0),
    (1, 1, 3, 1, 0.0),
    (1, 2, 1, 1, 0.6),
    (1, 2, 2, 1, 0.0),
    (1, 2, 3, 1, 0.0),
    (2, 1, 1, 1, 0.6),
    (2, 1, 2, 1, 0.6),
    (2, 1, 3, 1, 0.6),
    (2, 2, 1, 1, 0.84375),
    (2, 2, 2, 1, 0.84375),
    (2, 2, 3, 1, 1.0125),
    (3, 1, 1, 1, 0.6),
    (3, 1, 2, 1, 0.6),
    (3, 1, 3, 1, 0.6),
    (3, 2, 1, 1, 0.84375),
    (3, 2, 2, 1, 0.73125),
    (3, 2, 3, 1, 1.125),
]

for entry in quantity_data
    period, scenario, subperiod, bid_segment, quantity = entry
    bidding_group_quantity_offer[1, 1, bid_segment, subperiod, scenario, period] = quantity
end

price_data = [
    (1, 1, 1, 1, 122.800003),
    (1, 1, 2, 1, 122.800003),
    (1, 1, 3, 1, 122.800003),
]

for entry in price_data
    period, scenario, subperiod, bid_segment, price = entry
    bidding_group_price_offer[1, 1, bid_segment, subperiod, scenario, period] = price
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
    unit = "MW",
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
