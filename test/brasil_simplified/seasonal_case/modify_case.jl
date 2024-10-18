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

# Store information from the base case
number_of_scenarios_base_case = number_of_scenarios

# Group stages into seasons
months_per_stage = 3

# If this is 0, the first season has months [1, 2, 3]
# If this is 1, the first season has months [2, 3, 4]
# If this is -1, the first season has months [12, 1, 2]
# And so on...
season_start_delta = 0

# Update configurations
number_of_stages = 4
number_of_scenarios *= months_per_stage
block_duration_in_hours = 90.0

IARA.update_configuration!(db;
    number_of_stages = number_of_stages,
    number_of_scenarios = number_of_scenarios,
    block_duration_in_hours = [block_duration_in_hours for _ in 1:number_of_blocks],
)

# =====================================================
# Modify CSV files
# =====================================================

seasonal_inflow = zeros(number_of_hydro_plants, number_of_blocks, number_of_scenarios, number_of_stages)
seasonal_demand = zeros(number_of_buses, number_of_blocks, number_of_scenarios, number_of_stages)

for monthly_scenario in 1:number_of_scenarios_base_case
    seasonal_scenario = (monthly_scenario - 1) * months_per_stage + 1
    seasonal_scenarios = seasonal_scenario:(seasonal_scenario+months_per_stage-1)
    for seasonal_stage in 1:number_of_stages
        monthly_stage = mod1((seasonal_stage - 1) * months_per_stage + 1 + season_start_delta, 12)
        monthly_stages = mod1.(monthly_stage:(monthly_stage+months_per_stage-1), 12)
        for month in 1:months_per_stage
            seasonal_inflow[:, :, seasonal_scenarios[month], seasonal_stage] =
                inflow[:, :, monthly_scenario, monthly_stages[month]]
            seasonal_demand[:, :, seasonal_scenarios[month], seasonal_stage] =
                demand[:, :, monthly_scenario, monthly_stages[month]]
        end
    end
end

# Write to file
IARA.write_timeseries_file(
    joinpath(PATH, "inflow"),
    seasonal_inflow;
    dimensions = ["stage", "scenario", "block"],
    labels = ["hyd_$(bus_labels[h])_gauging_station" for h in 1:number_of_hydro_plants],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "m3/s",
)

# Write to file
IARA.write_timeseries_file(
    joinpath(PATH, "demand"),
    seasonal_demand;
    dimensions = ["stage", "scenario", "block"],
    labels = ["dem_$label" for label in bus_labels],
    time_dimension = "stage",
    dimension_size = [number_of_stages, number_of_scenarios, number_of_blocks],
    initial_date = "2020-01-01T00:00:00",
    unit = "GWh",
)

IARA.close_study!(db)
