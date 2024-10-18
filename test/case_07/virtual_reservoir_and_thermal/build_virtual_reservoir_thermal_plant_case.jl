db = load_study(PATH; read_only = false)

add_bidding_group!(db;
    label = "bg_1",
    assetowner_id = "asset_owner_1",
    simple_bid_max_segments = 2,
)

add_thermal_plant!(db;
    label = "ter_1",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        min_generation = 0.0,
        max_generation = 100.0,
        om_cost = 10.0,
    ),
    biddinggroup_id = "bg_1",
    has_commitment = 0,
    bus_id = "bus_1",
)

add_thermal_plant!(db;
    label = "ter_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = 1,
        min_generation = 0.0,
        max_generation = 100.0,
        om_cost = 20.0,
    ),
    biddinggroup_id = "bg_1",
    has_commitment = 0,
    bus_id = "bus_1",
)

close_study!(db)
