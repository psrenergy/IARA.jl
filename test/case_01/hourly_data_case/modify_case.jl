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

# Modify the subperiod duration in the database
new_subperiod_duration = 24.0
IARA.update_configuration!(db;
    subperiod_duration_in_hours = [new_subperiod_duration for _ in 1:number_of_subperiods],
)
IARA.update_hydro_unit!(
    db,
    "hyd_1";
    initial_volume = 12.0 * m3_per_second_to_hm3 * (new_subperiod_duration / subperiod_duration_in_hours),
)
IARA.update_hydro_unit_time_series_parameter!(
    db,
    "hyd_1",
    "max_volume",
    30.0 * m3_per_second_to_hm3 * (new_subperiod_duration / subperiod_duration_in_hours);
    date_time = DateTime(0),
)

# Create hourly inflow
number_of_hours = Int(number_of_subperiods * new_subperiod_duration)
hourly_inflow = zeros(1, number_of_hours, number_of_scenarios, number_of_periods)
for scen in 1:number_of_scenarios
    hourly_inflow[:, :, scen, :] .+= (scen - 1) / 2
    if scen > 1
        for hour in 1:number_of_hours
            inflow_perturbation = ((hour % 3) - 1) * 0.25
            hourly_inflow[:, hour, scen, :] .+= inflow_perturbation
        end
    end
end
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    hourly_inflow;
    dimensions = ["period", "scenario", "hour"],
    labels = ["hyd_1_gauging_station"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_hours],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

# Create hour subperiod mapping
hour_subperiod_map = zeros(1, number_of_hours, number_of_periods)
for hour in 1:number_of_hours
    hour_subperiod_map[:, hour, :] .= ceil(hour / new_subperiod_duration)
end
IARA.write_timeseries_file(
    joinpath(PATH, "hour_subperiod_map"),
    hour_subperiod_map;
    dimensions = ["period", "hour"],
    labels = ["hb_map"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_hours],
    initial_date = "2020-01-01T00:00:00",
    unit = " ",
)

IARA.link_time_series_to_file(
    db,
    "Configuration";
    hour_subperiod_map = "hour_subperiod_map",
)

demand = demand * new_subperiod_duration / subperiod_duration_in_hours

IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["period", "scenario", "subperiod"],
    labels = ["dem_1"],
    time_dimension = "period",
    dimension_size = [number_of_periods, number_of_scenarios, number_of_subperiods],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

IARA.close_study!(db)
