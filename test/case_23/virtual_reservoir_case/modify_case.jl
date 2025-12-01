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

number_of_hydro_units = 3
number_of_virtual_reservoirs = 1
number_of_vr_segments = 1
number_of_scenarios = 1
number_of_subscenarios = 1

IARA.update_configuration!(
    db;
    market_clearing_tiebreaker_weight_for_fcf = 0.01,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
    demand_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.EX_ANTE_AND_EX_POST,
    number_of_scenarios = number_of_scenarios,
    number_of_subscenarios = number_of_subscenarios,
)

# Add hydro units and virtual reservoir

IARA.add_hydro_unit!(db;
    label = "Hidro 1",
    initial_volume = 8.0,
    bus_id = "Sistema",
    biddinggroup_id = "Peaker 1",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.036,
        max_generation = 65.0,
        max_turbining = 1900.0,
        min_volume = 0.0,
        max_volume = 15.0,
        om_cost = 0.0,
    ),
)

IARA.add_hydro_unit!(db;
    label = "Hidro 2",
    initial_volume = 8.0,
    bus_id = "Sistema",
    biddinggroup_id = "Peaker 2",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.036,
        max_generation = 65.0,
        max_turbining = 1900.0,
        min_volume = 0.0,
        max_volume = 15.0,
        om_cost = 0.0,
    ),
)

IARA.add_hydro_unit!(db;
    label = "Hidro 3",
    initial_volume = 8.0,
    bus_id = "Sistema",
    biddinggroup_id = "Peaker 3",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.036,
        max_generation = 65.0,
        max_turbining = 1900.0,
        min_volume = 0.0,
        max_volume = 15.0,
        om_cost = 0.0,
    ),
)

IARA.add_virtual_reservoir!(
    db;
    label = "Reservatorio Virtual",
    assetowner_id = [
        "Agente Termico 1",
        "Agente Termico 2",
        "Agente Termico 3",
        "Agente Peaker 1",
        "Agente Peaker 2",
        "Agente Peaker 3",
    ],
    inflow_allocation = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0],
    initial_energy_account_share = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0],
    hydrounit_id = ["Hidro 1", "Hidro 2", "Hidro 3"],
)

IARA.update_thermal_unit_time_series_parameter!(
    db,
    "Termica 1",
    "om_cost",
    90.0;
    date_time = DateTime(0),
)

IARA.update_thermal_unit_time_series_parameter!(
    db,
    "Termica 2",
    "om_cost",
    100.0;
    date_time = DateTime(0),
)

IARA.update_thermal_unit_time_series_parameter!(
    db,
    "Termica 3",
    "om_cost",
    110.0;
    date_time = DateTime(0),
)

IARA.update_thermal_unit_time_series_parameter!(
    db,
    "Peaker 1",
    "om_cost",
    180.0;
    date_time = DateTime(0),
)

IARA.update_thermal_unit_time_series_parameter!(
    db,
    "Peaker 2",
    "om_cost",
    200.0;
    date_time = DateTime(0),
)

IARA.update_thermal_unit_time_series_parameter!(
    db,
    "Peaker 3",
    "om_cost",
    220.0;
    date_time = DateTime(0),
)

# Link and write time series files

IARA.link_time_series_to_file(
    db,
    "Configuration";
    fcf_cuts = "cuts.json",
)

inflow_ex_ante = zeros(number_of_hydro_units, number_of_subperiods, number_of_scenarios, number_of_periods) .+ 700.0
IARA.write_timeseries_file(
    joinpath(PATH, "inflow_ex_ante"),
    inflow_ex_ante;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["Hidro 1", "Hidro 2", "Hidro 3"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "m3/s",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    inflow_ex_ante = "inflow_ex_ante",
)

max_demand = 400.0
demand_ex_ante = [280.0, 580.0, 630.0, 350.0]
demand_ex_post = [295.0, 565.0, 615.0, 335.0]

demand_factor_ex_ante = zeros(number_of_buses, number_of_subperiods, number_of_scenarios, number_of_periods)
demand_factor_ex_post =
    zeros(number_of_buses, number_of_subperiods, number_of_subscenarios * 3, number_of_scenarios, number_of_periods)
for period in 1:number_of_periods
    demand_factor_ex_ante[:, :, :, period] .= demand_ex_ante[period] / max_demand
    demand_factor_ex_post[:, :, 1, :, period] .= demand_ex_post[period] / max_demand
    demand_factor_ex_post[:, :, 2, :, period] .= demand_ex_ante[period] / max_demand * 1.2
    demand_factor_ex_post[:, :, 3, :, period] .= demand_ex_ante[period] / max_demand * 0.8
end

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_ante"),
    demand_factor_ex_ante;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["Demanda"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)

IARA.link_time_series_to_file(
    db,
    "DemandUnit";
    demand_ex_ante = "demand_ex_ante",
)

IARA.write_timeseries_file(
    joinpath(PATH, "demand_ex_post"),
    demand_factor_ex_post;
    dimensions = ["period", "scenario", "subscenario", "subperiod"],
    labels = ["Demanda"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subscenarios * 3, number_of_subperiods],
    initial_date = "2025-01-01T00:00:00",
    unit = "p.u.",
)

# Generate zero bids for interface call validation

IARA.link_time_series_to_file(
    db,
    "VirtualReservoir";
    quantity_bid = "virtual_reservoir_energy_bid",
    price_bid = "virtual_reservoir_price_bid",
)

vr_price_bid = zeros(
    number_of_virtual_reservoirs,
    number_of_asset_owners,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)

map = Dict(
    "Reservatorio Virtual" => [
        "Agente Termico 1",
        "Agente Termico 2",
        "Agente Termico 3",
        "Agente Peaker 1",
        "Agente Peaker 2",
        "Agente Peaker 3",
    ],
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "virtual_reservoir_price_bid"),
    vr_price_bid;
    dimensions = ["period", "scenario", "bid_segment"],
    labels_virtual_reservoirs = ["Reservatorio Virtual"],
    labels_asset_owners = [
        "Agente Termico 1",
        "Agente Termico 2",
        "Agente Termico 3",
        "Agente Peaker 1",
        "Agente Peaker 2",
        "Agente Peaker 3",
    ],
    virtual_reservoirs_to_asset_owners_map = map,
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_vr_segments,
    ],
    initial_date = "2025",
    unit = "\$/MWh",
)

vr_quantity_bid = zeros(
    number_of_virtual_reservoirs,
    number_of_asset_owners,
    number_of_vr_segments,
    number_of_scenarios,
    number_of_periods,
)

IARA.write_virtual_reservoir_bids_time_series_file(
    joinpath(PATH, "virtual_reservoir_energy_bid"),
    vr_quantity_bid;
    dimensions = ["period", "scenario", "bid_segment"],
    labels_virtual_reservoirs = ["Reservatorio Virtual"],
    labels_asset_owners = [
        "Agente Termico 1",
        "Agente Termico 2",
        "Agente Termico 3",
        "Agente Peaker 1",
        "Agente Peaker 2",
        "Agente Peaker 3",
    ],
    virtual_reservoirs_to_asset_owners_map = map,
    time_dimension = "period",
    dimension_size = [
        number_of_periods,
        number_of_scenarios,
        number_of_vr_segments,
    ],
    initial_date = "2025",
    unit = "MWh",
)

IARA.close_study!(db)
