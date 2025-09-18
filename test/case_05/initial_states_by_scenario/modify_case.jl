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

IARA.update_gauging_station!(db,
    "gs_1";
    inflow_initial_state_variation_type = IARA.GaugingStation_InflowInitialStateVariationType.BY_SCENARIO,
)

IARA.update_hydro_unit!(db,
    "hyd_1";
    initial_volume_variation_type = IARA.HydroUnit_InitialVolumeVariationType.BY_SCENARIO,
)

parp_max_lags = 6

old_initial_volume = 12.0 * m3_per_second_to_hm3
initial_volume_by_scenario = zeros(1, number_of_scenarios)

old_inflow_initial_state = historical_inflow_values[end-parp_max_lags+1:end]
inflow_initial_state_by_scenario = zeros(1, parp_max_lags, number_of_scenarios)

for scenario in 1:number_of_scenarios
    initial_volume_by_scenario[1, scenario] = old_initial_volume * (scenario / 2.5)
    inflow_initial_state_by_scenario[1, :, scenario] = old_inflow_initial_state .* (scenario / 2.5)
end

IARA.write_timeseries_file(
    joinpath(PATH, "initial_volume_by_scenario"),
    initial_volume_by_scenario;
    dimensions = ["scenario"],
    labels = ["hyd_1"],
    time_dimension = "scenario", # this is wrong, but a time_dimension is required
    dimension_size = [number_of_scenarios],
    initial_date = "2020-01-01T00:00:00",
    unit = "hm3",
)
if !ispath(joinpath(PATH, "parp"))
    mkdir(joinpath(PATH, "parp"))
end
IARA.write_timeseries_file(
    joinpath(PATH, "parp", "inflow_initial_state_by_scenario"),
    inflow_initial_state_by_scenario;
    dimensions = ["scenario", "lag"],
    labels = ["gs_1"],
    time_dimension = "scenario", # this is wrong, but a time_dimension is required
    dimension_size = [number_of_scenarios, parp_max_lags],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

IARA.link_time_series_to_file(
    db,
    "HydroUnit";
    initial_volume_by_scenario = "initial_volume_by_scenario",
)
IARA.link_time_series_to_file(
    db,
    "GaugingStation";
    inflow_initial_state_by_scenario = "inflow_initial_state_by_scenario",
)

IARA.close_study!(db)
