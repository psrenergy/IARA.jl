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

IARA.update_configuration!(db; hydro_spillage_cost = 1e-3)

# Add second gauging station and hydro unit
IARA.add_gauging_station!(db;
    label = "gs_2",
    historical_inflow = DataFrame(;
        date_time = historical_inflow_dates,
        historical_inflow = reverse(historical_inflow_values) .+ historical_inflow_values,
    ),
)
# IARA.add_hydro_unit!(db;
#     label = "hyd_2",
#     parameters = DataFrame(;
#         date_time = [DateTime(0), DateTime("2020-03-01T00:00:00")],
#         existing = [Int(IARA.HydroUnit_Existence.DOES_NOT_EXIST), Int(IARA.HydroUnit_Existence.EXISTS)],
#         production_factor = [0.5, missing],
#         min_generation = [0.0, missing],
#         max_generation = [3.5, missing],
#         max_turbining = [7.0, missing],
#         min_volume = [0.0, missing],
#         max_volume = [0.0, missing],
#         min_outflow = [0.0, missing],
#         om_cost = [0.0, missing],
#     ),
#     initial_volume = 0.0,
#     bus_id = "bus_2",
#     gaugingstation_id = "gs_2",
# )
IARA.add_hydro_unit!(db;
    label = "hyd_2",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.HydroUnit_Existence.DOES_NOT_EXIST)],
        production_factor = [0.5],
        min_generation = [0.0],
        max_generation = [3.5],
        max_turbining = [7.0],
        min_volume = [0.0],
        max_volume = [0.0],
        min_outflow = [0.0],
        om_cost = [0.0],
    ),
    initial_volume = 0.0,
    bus_id = "bus_2",
    gaugingstation_id = "gs_2",
)

IARA.add_hydro_unit!(db;
    label = "hyd_3",
    parameters = DataFrame(;
        date_time = [DateTime(0)],
        existing = [Int(IARA.HydroUnit_Existence.EXISTS)],
        production_factor = [0.5],
        min_generation = [0.0],
        max_generation = [3.5],
        max_turbining = [7.0],
        min_volume = [0.0],
        max_volume = [0.0],
        min_outflow = [0.0],
        om_cost = [0.0],
    ),
    initial_volume = 0.0,
    bus_id = "bus_2",
    gaugingstation_id = "gs_2",
)

# Set hydro relations
IARA.update_gauging_station_relation!(
    db,
    "gs_1";
    collection = "GaugingStation",
    relation_type = "downstream",
    related_label = "gs_2",
)
IARA.set_hydro_turbine_to!(
    db,
    "hyd_1",
    "hyd_2",
)
IARA.set_hydro_spill_to!(
    db,
    "hyd_1",
    "hyd_2",
)

demand[1, 1, 3, 1] += 0.2171 / max_demand
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "p.u.",
)

IARA.close_study!(db)
