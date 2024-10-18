PRAGMA user_version = 1;
PRAGMA foreign_keys = ON;

CREATE TABLE Configuration (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL DEFAULT "Configuration",
    number_of_stages INTEGER NOT NULL,
    number_of_scenarios INTEGER NOT NULL,
    number_of_blocks INTEGER NOT NULL,
    number_of_nodes INTEGER,
    number_of_subscenarios INTEGER NOT NULL DEFAULT 1,
    iteration_limit INTEGER,
    initial_date_time TEXT NOT NULL DEFAULT "2024-01-01",
    stage_type INTEGER NOT NULL DEFAULT 0,
    run_mode INTEGER NOT NULL DEFAULT 0,
    policy_graph_type INTEGER NOT NULL DEFAULT 1,
    hydro_balance_block_resolution INTEGER DEFAULT 0,
    use_binary_variables INTEGER NOT NULL DEFAULT 0,
    loop_blocks_for_thermal_constraints INTEGER,
    yearly_discount_rate REAL NOT NULL,
    yearly_duration_in_hours REAL NOT NULL DEFAULT 8760.0,
    demand_deficit_cost REAL NOT NULL,
    hydro_minimum_outflow_violation_cost REAL,
    hydro_spillage_cost REAL NOT NULL DEFAULT 0.0,
    aggregate_buses_for_strategic_bidding INTEGER,
    parp_max_lags INTEGER DEFAULT 6,
    inflow_source INTEGER NOT NULL DEFAULT 1,
    clearing_bid_source INTEGER NOT NULL DEFAULT 0,
    clearing_hydro_representation INTEGER NOT NULL DEFAULT 0,
    ex_post_physical_hydro_representation INTEGER NOT NULL DEFAULT 0,
    clearing_integer_variables INTEGER NOT NULL DEFAULT 0,
    clearing_network_representation INTEGER NOT NULL DEFAULT 0,
    settlement_type INTEGER NOT NULL DEFAULT 0,
    make_whole_payments INTEGER NOT NULL DEFAULT 0,
    price_cap INTEGER NOT NULL DEFAULT 0,
    number_of_virtual_reservoir_bidding_segments INTEGER
) STRICT;

CREATE TABLE Configuration_vector_block_duration (
    id INTEGER, 
    vector_index INTEGER NOT NULL,
    block_duration_in_hours REAL,
    FOREIGN KEY(id) REFERENCES Configuration(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

CREATE TABLE Configuration_time_series_files (
    hour_block_map TEXT,
    fcf_cuts TEXT
) STRICT;

CREATE TABLE RenewablePlant (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    technology_type INTEGER,
    bus_id INTEGER,
    biddinggroup_id INTEGER,
    FOREIGN KEY(bus_id) REFERENCES Bus(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(biddinggroup_id) REFERENCES BiddingGroup(id) ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE RenewablePlant_time_series_files (
    generation TEXT NOT NULL
) STRICT;

CREATE TABLE RenewablePlant_time_series_parameters (
    id INTEGER, 
    date_time TEXT NOT NULL,
    existing INTEGER,
    max_generation REAL,
    om_cost REAL,
    curtailment_cost REAL,
    FOREIGN KEY(id) REFERENCES RenewablePlant(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, date_time)
) STRICT;

CREATE TABLE HydroPlant (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    initial_volume REAL,
    initial_volume_type INTEGER DEFAULT 2,
    has_commitment INTEGER DEFAULT 0,
    operation_type INTEGER DEFAULT 0,
    bus_id INTEGER,
    biddinggroup_id INTEGER,
    gaugingstation_id INTEGER,
    hydroplant_turbine_to INTEGER,
    hydroplant_spill_to INTEGER,
    FOREIGN KEY(bus_id) REFERENCES Bus(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(biddinggroup_id) REFERENCES BiddingGroup(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(gaugingstation_id) REFERENCES GaugingStation(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(hydroplant_turbine_to) REFERENCES HydroPlant(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(hydroplant_spill_to) REFERENCES HydroPlant(id) ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE HydroPlant_time_series_files (
    inflow TEXT NOT NULL
) STRICT;

CREATE TABLE HydroPlant_time_series_parameters (
    id INTEGER, 
    date_time TEXT NOT NULL,
    existing INTEGER,
    production_factor REAL,
    min_generation REAL,
    max_generation REAL,
    max_turbining REAL,
    min_volume REAL,
    max_volume REAL,
    min_outflow REAL,
    om_cost REAL,
    FOREIGN KEY(id) REFERENCES HydroPlant(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, date_time)
) STRICT;

CREATE TABLE GaugingStation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    gaugingstation_downstream INTEGER,
    FOREIGN KEY(gaugingstation_downstream) REFERENCES GaugingStation(id) ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE GaugingStation_time_series_historical_inflow (
    id INTEGER, 
    date_time TEXT,
    historical_inflow REAL,
    FOREIGN KEY(id) REFERENCES GaugingStation(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, date_time)
) STRICT;

CREATE TABLE ThermalPlant (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    has_commitment INTEGER DEFAULT 0 NOT NULL,
    max_ramp_up REAL,
    max_ramp_down REAL,
    min_uptime REAL,
    max_uptime REAL,
    min_downtime REAL,
    max_startups INTEGER,
    max_shutdowns INTEGER,
    shutdown_cost REAL NOT NULL DEFAULT 0.0,
    commitment_initial_condition INTEGER,
    generation_initial_condition REAL,
    uptime_initial_condition REAL,
    downtime_initial_condition REAL,
    bus_id INTEGER,
    biddinggroup_id INTEGER,
    FOREIGN KEY(bus_id) REFERENCES Bus(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(biddinggroup_id) REFERENCES BiddingGroup(id) ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE ThermalPlant_time_series_parameters (
    id INTEGER, 
    date_time TEXT NOT NULL,
    existing INTEGER,
    startup_cost REAL,
    min_generation REAL,
    max_generation REAL,
    om_cost REAL,
    FOREIGN KEY(id) REFERENCES ThermalPlant(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, date_time)
) STRICT;

CREATE TABLE Demand (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    demand_type INTEGER NOT NULL DEFAULT 0,
    max_shift_up REAL,
    max_shift_down REAL,
    curtailment_cost REAL,
    max_curtailment REAL,
    bus_id INTEGER,
    FOREIGN KEY(bus_id) REFERENCES Bus(id) ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE Demand_time_series_parameters (
    id INTEGER, 
    date_time TEXT NOT NULL,
    existing INTEGER,
    FOREIGN KEY(id) REFERENCES Demand(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, date_time)
) STRICT;

CREATE TABLE Demand_time_series_files (
    demand TEXT NOT NULL,
    elastic_demand_price TEXT,
    demand_window TEXT
) STRICT;

CREATE TABLE Zone (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL
) STRICT;

CREATE TABLE Bus (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    zone_id INTEGER,
    FOREIGN KEY(zone_id) REFERENCES Zone(id) ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE DCLine (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    bus_to INTEGER,
    bus_from INTEGER,
    FOREIGN KEY(bus_to) REFERENCES Bus(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(bus_from) REFERENCES Bus(id)ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE DCLine_time_series_parameters (
    id INTEGER, 
    date_time TEXT NOT NULL,
    existing INTEGER,
    capacity_to REAL,
    capacity_from REAL,
    FOREIGN KEY(id) REFERENCES DCLine(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, date_time)
) STRICT;

CREATE TABLE Branch (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    line_model INTEGER NOT NULL DEFAULT 0,
    bus_to INTEGER,
    bus_from INTEGER,
    FOREIGN KEY(bus_to) REFERENCES Bus(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(bus_from) REFERENCES Bus(id) ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE Branch_time_series_parameters (
    id INTEGER, 
    date_time TEXT NOT NULL,
    existing INTEGER,
    capacity REAL,
    reactance REAL,
    FOREIGN KEY(id) REFERENCES Branch(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, date_time)
) STRICT;

CREATE TABLE Battery (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    initial_storage REAL,
    bus_id INTEGER,
    biddinggroup_id INTEGER,
    FOREIGN KEY(bus_id) REFERENCES Bus(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY(biddinggroup_id) REFERENCES BiddingGroup(id) ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE Battery_time_series_parameters (
    id INTEGER, 
    date_time TEXT NOT NULL,
    existing INTEGER,
    min_storage REAL,
    max_storage REAL,
    max_capacity REAL,
    om_cost REAL,
    FOREIGN KEY(id) REFERENCES Battery(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, date_time)
) STRICT;

CREATE TABLE AssetOwner (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    price_type INTEGER NOT NULL DEFAULT 1
) STRICT;

CREATE TABLE AssetOwner_vector_markup (
    id INTEGER, 
    vector_index INTEGER NOT NULL,
    risk_factor REAL,
    segment_fraction REAL,
    FOREIGN KEY(id) REFERENCES AssetOwner(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;


CREATE TABLE BiddingGroup_time_series_files (
    quantity_offer TEXT NOT NULL,
    price_offer TEXT NOT NULL,
    quantity_offer_multihour TEXT,
    price_offer_multihour TEXT,
    parent_profile_multihour TEXT,
    complementary_grouping_multihour TEXT,
    minimum_activation_level_multihour TEXT
) STRICT;

CREATE TABLE BiddingGroup (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    bid_type INTEGER NOT NULL DEFAULT 0,
    simple_bid_max_segments INTEGER DEFAULT 0,
    multihour_bid_max_profiles INTEGER DEFAULT 0,
    assetowner_id INTEGER,
    FOREIGN KEY(assetowner_id) REFERENCES AssetOwner(id) ON UPDATE CASCADE ON DELETE SET NULL
) STRICT;

CREATE TABLE BiddingGroup_vector_markup (
    id INTEGER, 
    vector_index INTEGER NOT NULL,
    risk_factor REAL,
    segment_fraction REAL,
    FOREIGN KEY(id) REFERENCES BiddingGroup(id) ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

CREATE TABLE VirtualReservoir (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL
) STRICT;

CREATE TABLE VirtualReservoir_time_series_files (
    quantity_offer TEXT NOT NULL,
    price_offer TEXT NOT NULL
) STRICT;

CREATE TABLE VirtualReservoir_vector_owner_and_allocation (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    assetowner_id INTEGER,
    inflow_allocation REAL NOT NULL,
    FOREIGN KEY(id) REFERENCES VirtualReservoir(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(assetowner_id) REFERENCES AssetOwner(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

CREATE TABLE VirtualReservoir_vector_hydro_plant (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    hydroplant_id INTEGER,
    FOREIGN KEY(id) REFERENCES VirtualReservoir(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(hydroplant_id) REFERENCES HydroPlant(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

CREATE TABLE Reserve (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT UNIQUE NOT NULL,
    constraint_type INTEGER NOT NULL,
    direction INTEGER NOT NULL,
    violation_cost REAL NOT NULL,
    angular_coefficient REAL,
    linear_coefficient REAL
) STRICT;

CREATE TABLE Reserve_time_series_files (
    reserve_requirement TEXT NOT NULL
) STRICT;

CREATE TABLE Reserve_vector_thermal_plant (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    thermalplant_id INTEGER,
    FOREIGN KEY(id) REFERENCES Reserve(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(thermalplant_id) REFERENCES ThermalPlant(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

CREATE TABLE Reserve_vector_hydro_plant (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    hydroplant_id INTEGER,
    FOREIGN KEY(id) REFERENCES Reserve(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(hydroplant_id) REFERENCES HydroPlant(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;

CREATE TABLE Reserve_vector_battery (
    id INTEGER,
    vector_index INTEGER NOT NULL,
    battery_id INTEGER,
    FOREIGN KEY(id) REFERENCES Reserve(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(battery_id) REFERENCES Battery(id) ON DELETE SET NULL ON UPDATE CASCADE,
    PRIMARY KEY (id, vector_index)
) STRICT;