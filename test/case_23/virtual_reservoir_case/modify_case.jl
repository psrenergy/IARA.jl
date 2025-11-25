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

IARA.update_configuration!(
    db;
    market_clearing_tiebreaker_weight_for_fcf = 0.01,
    inflow_scenarios_files = IARA.Configurations_UncertaintyScenariosFiles.ONLY_EX_ANTE,
)

IARA.add_hydro_unit!(db;
    label = "Hidro 1",
    initial_volume = 1.5,
    bus_id = "Sistema",
    biddinggroup_id = "Peaker 1",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.1,
        max_generation = 40.0,
        max_turbining = 400.0,
        min_volume = 0.0,
        max_volume = 3.0,
        om_cost = 0.1,
    ),
)

IARA.add_hydro_unit!(db;
    label = "Hidro 2",
    initial_volume = 1.5,
    bus_id = "Sistema",
    biddinggroup_id = "Peaker 2",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.1,
        max_generation = 40.0,
        max_turbining = 400.0,
        min_volume = 0.0,
        max_volume = 3.0,
        om_cost = 0.1,
    ),
)

IARA.add_hydro_unit!(db;
    label = "Hidro 3",
    initial_volume = 1.5,
    bus_id = "Sistema",
    biddinggroup_id = "Peaker 3",
    parameters = DataFrame(;
        date_time = DateTime(0),
        existing = Int(IARA.HydroUnit_Existence.EXISTS),
        production_factor = 0.1,
        max_generation = 40.0,
        max_turbining = 400.0,
        min_volume = 0.0,
        max_volume = 3.0,
        om_cost = 0.1,
    ),
)

inflow_ex_ante = zeros(number_of_hydro_units, number_of_subperiods, number_of_scenarios, number_of_periods) .+ 200.0
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

IARA.link_time_series_to_file(
    db,
    "Configuration";
    fcf_cuts = "cuts.json",
)

IARA.close_study!(db)
