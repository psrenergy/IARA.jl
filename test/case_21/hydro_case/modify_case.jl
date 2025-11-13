#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = IARA.load_study(PATH; read_only = false)

IARA.update_configuration!(db;
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_POST,
    construction_type_ex_ante_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_ante_commercial = IARA.Configurations_ConstructionType.SKIP,
    construction_type_ex_post_physical = IARA.Configurations_ConstructionType.HYBRID,
    construction_type_ex_post_commercial = IARA.Configurations_ConstructionType.SKIP,
)

IARA.add_asset_owner!(
    db;
    label = "Agente Hidro 1",
    virtual_reservoir_energy_account_upper_bound = [0.5, 1.0],
    risk_factor_for_virtual_reservoir_bids = [0.1, 0.0],
    purchase_discount_rate = [0.1],
)
IARA.add_asset_owner!(
    db;
    label = "Agente Hidro 2",
    virtual_reservoir_energy_account_upper_bound = [0.5, 1.0],
    risk_factor_for_virtual_reservoir_bids = [0.3, 0.2],
    purchase_discount_rate = [0.1],
)

# BG
IARA.add_bidding_group!(
    db;
    label = "Hidro 1",
    assetowner_id = "Agente Hidro 1",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    fixed_cost = 1000.0,
)
IARA.add_bidding_group!(
    db;
    label = "Hidro 2",
    assetowner_id = "Agente Hidro 2",
    risk_factor = [0.0],
    segment_fraction = [1.0],
    fixed_cost = 1200.0,
)

# Hydro units
IARA.add_hydro_unit!(db;
    label = "Hidro 1 M",
    initial_volume = 0.05,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1.0,
        max_generation = 100.0,
        min_volume = 0.0,
        max_turbining = 100.0,
        max_volume = 1.0,
        min_outflow = 0.0,
        om_cost = 10.0,
    ),
    bus_id = "Sistema",
    biddinggroup_id = "Hidro 1",
)
IARA.add_hydro_unit!(db;
    label = "Hidro 1 J",
    initial_volume = 0.0,
    intra_period_operation = IARA.HydroUnit_IntraPeriodOperation.CYCLIC_WITH_FLEXIBLE_START,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1.0,
        max_generation = 100.0,
        min_volume = 0.0,
        max_turbining = 100.0,
        max_volume = 0.0,
        min_outflow = 0.0,
        om_cost = 10.0,
    ),
    bus_id = "Sistema",
    biddinggroup_id = "Hidro 1",
)

IARA.add_hydro_unit!(db;
    label = "Hidro 2 M",
    initial_volume = 0.05,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1.0,
        max_generation = 100.0,
        min_volume = 0.0,
        max_turbining = 100.0,
        max_volume = 1.0,
        min_outflow = 0.0,
        om_cost = 10.0,
    ),
    bus_id = "Sistema",
    biddinggroup_id = "Hidro 2",
)
IARA.add_hydro_unit!(db;
    label = "Hidro 2 J",
    initial_volume = 0.0,
    intra_period_operation = IARA.HydroUnit_IntraPeriodOperation.CYCLIC_WITH_FLEXIBLE_START,
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 1.0,
        max_generation = 100.0,
        min_volume = 0.0,
        max_turbining = 100.0,
        max_volume = 0.0,
        min_outflow = 0.0,
        om_cost = 10.0,
    ),
    bus_id = "Sistema",
    biddinggroup_id = "Hidro 2",
)

IARA.set_hydro_turbine_to!(db, "Hidro 1 M", "Hidro 2 J")
IARA.set_hydro_spill_to!(db, "Hidro 1 M", "Hidro 2 J")

IARA.set_hydro_turbine_to!(db, "Hidro 2 M", "Hidro 1 J")
IARA.set_hydro_spill_to!(db, "Hidro 2 M", "Hidro 1 J")

# VR
IARA.add_virtual_reservoir!(db;
    label = "Cascata 1",
    assetowner_id = ["Agente Hidro 1", "Agente Hidro 2"],
    inflow_allocation = [0.5, 0.5],
    initial_energy_account_share = [0.5, 0.5],
    hydrounit_id = ["Hidro 1 M", "Hidro 2 J"],
)

IARA.add_virtual_reservoir!(db;
    label = "Cascata 2",
    assetowner_id = ["Agente Hidro 1", "Agente Hidro 2"],
    inflow_allocation = [0.5, 0.5],
    initial_energy_account_share = [0.5, 0.5],
    hydrounit_id = ["Hidro 1 J", "Hidro 2 M"],
)

# Time series data
# ----------------
# Inflow
inflow = zeros(4, number_of_subperiods, number_of_subscenarios, number_of_scenarios, number_of_periods)
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    inflow;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Hidro 1 M", "Hidro 1 J", "Hidro 2 M", "Hidro 2 J"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "m3/s",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow_ex_post = "inflow",
)

# VR Bids
number_of_virtual_reservoirs = 2
number_of_asset_owners = 2
number_of_vr_segments = 2

vr_quantity_bid = zeros(
    number_of_virtual_reservoirs,
    number_of_asset_owners,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)
vr_price_bid = zeros(
    number_of_virtual_reservoirs,
    number_of_asset_owners,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)

# VR 1, AO 1
vr_quantity_bid[1, 1, 1, :, :] .= 100.0
vr_quantity_bid[1, 1, 2, :, :] .= 100.0
vr_price_bid[1, 1, 1, :, :] .= 30.0
vr_price_bid[1, 1, 2, :, :] .= 100.0

# VR 2, AO 1
vr_quantity_bid[2, 1, 1, :, :] .= 100.0
vr_quantity_bid[2, 1, 2, :, :] .= 100.0
vr_price_bid[2, 1, 1, :, :] .= 33.0
vr_price_bid[2, 1, 2, :, :] .= 110.0

# VR 1, AO 2
vr_quantity_bid[1, 2, 1, :, :] .= 100.0
vr_quantity_bid[1, 2, 2, :, :] .= 100.0
vr_price_bid[1, 2, 1, :, :] .= 36.0
vr_price_bid[1, 2, 2, :, :] .= 120.0

# VR 2, AO 2 
vr_quantity_bid[2, 2, 1, :, :] .= 100.0
vr_quantity_bid[2, 2, 2, :, :] .= 100.0
vr_price_bid[2, 2, 1, :, :] .= 39.0
vr_price_bid[2, 2, 2, :, :] .= 130.0

vr_ao_map = Dict(
    "Cascata 1" => ["Agente Hidro 1", "Agente Hidro 2"],
    "Cascata 2" => ["Agente Hidro 1", "Agente Hidro 2"],
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "vr_quantity_bid"),
    vr_quantity_bid;
    dimensions = ["period", "scenario", "bid_segment"],
    labels_virtual_reservoirs = ["Cascata 1", "Cascata 2"],
    labels_asset_owners = ["Agente Hidro 1", "Agente Hidro 2"],
    virtual_reservoirs_to_asset_owners_map = vr_ao_map,
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_vr_segments,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "MWh",
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "vr_price_bid"),
    vr_price_bid;
    dimensions = ["period", "scenario", "bid_segment"],
    labels_virtual_reservoirs = ["Cascata 1", "Cascata 2"],
    labels_asset_owners = ["Agente Hidro 1", "Agente Hidro 2"],
    virtual_reservoirs_to_asset_owners_map = vr_ao_map,
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_vr_segments,
    ],
    initial_date = "2025-01-01T00:00:00",
    unit = "\$/MWh",
)

IARA.link_time_series_to_file(
    db,
    "VirtualReservoir";
    quantity_bid = "vr_quantity_bid",
    price_bid = "vr_price_bid",
)

# FCF
# ---
IARA.link_time_series_to_file(
    db,
    "Configuration";
    fcf_cuts = "cuts.json",
)

IARA.close_study!(db)
