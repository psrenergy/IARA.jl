#  Copyright (c) 2024: PSR, CCEE (Câmara de Comercialização de Energia  
#      Elétrica), and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#############################################################################
# IARA
# See https://github.com/psrenergy/IARA.jl
#############################################################################

db = load_study(PATH; read_only = false)

# Modify the block duration in the database
new_block_duration = 24.0
update_configuration!(db;
    block_duration_in_hours = [new_block_duration for _ in 1:number_of_blocks],
)
update_hydro_plant!(
    db,
    "hyd_1";
    initial_volume = 12.0 * m3_per_second_to_hm3 * (new_block_duration / block_duration_in_hours),
)
update_hydro_plant_time_series_parameter!(
    db,
    "hyd_1",
    "max_volume",
    30.0 * m3_per_second_to_hm3 * (new_block_duration / block_duration_in_hours);
    date_time = DateTime(0),
)

# Create hourly inflow
number_of_hours = Int(number_of_blocks * new_block_duration)
hourly_inflow = zeros(1, number_of_hours, number_of_scenarios, number_of_stages)
for scen in 1:number_of_scenarios
    hourly_inflow[:, :, scen, :] .+= (scen - 1) / 2
    if scen > 1
        for hour in 1:number_of_hours
            inflow_perturbation = ((hour % 3) - 1) * 0.25
            hourly_inflow[:, hour, scen, :] .+= inflow_perturbation
        end
    end
end
write_timeseries_file(
    joinpath(PATH, "inflow"),
    hourly_inflow;
    dimensions = ["stage", "scenario", "hour"],
    labels = ["hyd_1_gauging_station"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_hours],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

# Create hour block mapping
hour_block_map = zeros(1, number_of_hours, number_of_stages)
for hour in 1:number_of_hours
    hour_block_map[:, hour, :] .= ceil(hour / new_block_duration)
end
write_timeseries_file(
    joinpath(PATH, "hour_block_map"),
    hour_block_map;
    dimensions = ["stage", "hour"],
    labels = ["hb_map"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_hours],
    initial_date = "2020-01-01T00:00:00",
    unit = " ",
)

link_time_series_to_file(
    db,
    "Configuration";
    hour_block_map = "hour_block_map",
)

demand = demand * new_block_duration / block_duration_in_hours

write_timeseries_file(
    joinpath(PATH, "demand"),
    demand;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_1"],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

close_study!(db)
